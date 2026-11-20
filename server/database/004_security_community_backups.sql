-- مكتبة القيّوم | توسيع الأمان والإشعارات والمجتمع والنسخ الاحتياطي
-- PostgreSQL 16+ | يُشغّل بعد 001_core_schema.sql و002_platform_modules.sql و003_catalog_import.sql
-- هذا مخطط قاعدة بيانات فقط؛ يحتاج API وخادماً ومفاتيح خارج المستودع لتفعيل الخدمات.
BEGIN;
SET search_path TO qayyum, public;

-- تفضيلات اللغة والتقويم والإشعارات لكل مستخدم
CREATE TABLE IF NOT EXISTS user_platform_preferences (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  interface_language VARCHAR(32) NOT NULL DEFAULT 'ar',
  text_direction VARCHAR(3) NOT NULL DEFAULT 'rtl' CHECK (text_direction IN ('rtl','ltr')),
  calendar_default VARCHAR(16) NOT NULL DEFAULT 'hijri' CHECK (calendar_default IN ('hijri','gregorian')),
  calendar_authority_mode VARCHAR(32) NOT NULL DEFAULT 'show_variations',
  timezone VARCHAR(80),
  profile_visibility VARCHAR(16) NOT NULL DEFAULT 'public' CHECK (profile_visibility IN ('public','private')),
  accessibility JSONB NOT NULL DEFAULT '{}'::jsonb,
  assistant_source_scope VARCHAR(32) NOT NULL DEFAULT 'unset' CHECK (assistant_source_scope IN ('unset','library_only','library_and_external')),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS notification_preferences (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  notification_kind VARCHAR(48) NOT NULL,
  in_app_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  browser_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  mobile_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  email_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  quiet_hours JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY(user_id, notification_kind)
);

-- اشتراكات إشعارات الويب/الهاتف: تُخزن المفاتيح مشفرة على مستوى التطبيق.
CREATE TABLE IF NOT EXISTS notification_endpoints (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  channel VARCHAR(16) NOT NULL CHECK (channel IN ('browser','mobile')),
  endpoint_ciphertext TEXT NOT NULL,
  key_material_ciphertext TEXT,
  device_label VARCHAR(180),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_notification_endpoints_user ON notification_endpoints(user_id) WHERE revoked_at IS NULL;

-- سجل محاولات الدخول والأجهزة والجلسات. لا تُخزن كلمات المرور أو رموز الجلسات الخام هنا.
CREATE TABLE IF NOT EXISTS security_events (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  event_kind VARCHAR(48) NOT NULL,
  outcome VARCHAR(24) NOT NULL CHECK (outcome IN ('success','failure','blocked','review')),
  device_fingerprint_hash TEXT,
  ip_prefix INET,
  event_details JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_security_events_user_time ON security_events(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS user_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  session_token_hash TEXT NOT NULL UNIQUE,
  device_label VARCHAR(180),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_user_sessions_active ON user_sessions(user_id, expires_at DESC) WHERE revoked_at IS NULL;

-- تهيئة بيانات المصادقة الثنائية المشفرة. السر لا يُحفظ كنص مكشوف.
CREATE TABLE IF NOT EXISTS user_mfa_methods (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  method_kind VARCHAR(24) NOT NULL CHECK (method_kind IN ('totp','passkey','recovery_code_set')),
  secret_ciphertext TEXT,
  public_key_data JSONB,
  enabled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  revoked_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_user_mfa_active ON user_mfa_methods(user_id) WHERE revoked_at IS NULL;

-- نقاط ومستويات المجموعات والقنوات. النقاط لا تُحتسب إلا من أحداث معتمدة.
CREATE TABLE IF NOT EXISTS community_level_rules (
  level_no SMALLINT PRIMARY KEY CHECK (level_no BETWEEN 1 AND 10),
  required_points INTEGER NOT NULL CHECK (required_points > 0),
  badge_name VARCHAR(120) NOT NULL,
  benefit_description TEXT NOT NULL
);
INSERT INTO community_level_rules(level_no, required_points, badge_name, benefit_description) VALUES
(1,1000,'وسام البداية','هوية مميزة للمجموعة أو القناة'),
(2,2000,'وسام النشاط','إبراز في قائمة النشطة'),
(3,4000,'وسام التفاعل','شارة المستوى في صفحة المجموعة'),
(4,8000,'وسام التميز','خيارات تخصيص للواجهة'),
(5,16000,'وسام النخبة','الظهور ضمن المجموعات المميزة'),
(6,32000,'وسام الريادة','مساحة عرض أكبر في الدليل'),
(7,64000,'وسام الاحتراف','إحصائيات متقدمة'),
(8,128000,'وسام الإبداع','خيارات تخصيص إضافية'),
(9,256000,'وسام السيادة','أولوية الظهور في الترشيحات'),
(10,512000,'وسام القيّوم','شارة أعلى مستوى وظهور مميز')
ON CONFLICT(level_no) DO UPDATE SET required_points=EXCLUDED.required_points,badge_name=EXCLUDED.badge_name,benefit_description=EXCLUDED.benefit_description;

CREATE TABLE IF NOT EXISTS community_scoring_weights (
  id SMALLINT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  research_content_percent SMALLINT NOT NULL DEFAULT 40,
  events_initiatives_percent SMALLINT NOT NULL DEFAULT 30,
  genuine_interaction_percent SMALLINT NOT NULL DEFAULT 20,
  member_growth_percent SMALLINT NOT NULL DEFAULT 10,
  CHECK (research_content_percent + events_initiatives_percent + genuine_interaction_percent + member_growth_percent = 100)
);
INSERT INTO community_scoring_weights(id) VALUES (1) ON CONFLICT(id) DO NOTHING;

CREATE TABLE IF NOT EXISTS community_point_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  space_id UUID NOT NULL REFERENCES community_spaces(id) ON DELETE CASCADE,
  submitted_by UUID REFERENCES users(id) ON DELETE SET NULL,
  event_kind VARCHAR(48) NOT NULL,
  points INTEGER NOT NULL CHECK (points > 0),
  evidence JSONB NOT NULL DEFAULT '{}'::jsonb,
  anti_abuse_status VARCHAR(24) NOT NULL DEFAULT 'pending' CHECK (anti_abuse_status IN ('pending','approved','rejected','reversed')),
  reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_community_point_events_space ON community_point_events(space_id, created_at DESC);

CREATE TABLE IF NOT EXISTS community_level_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  space_id UUID NOT NULL REFERENCES community_spaces(id) ON DELETE CASCADE,
  requested_level SMALLINT NOT NULL CHECK (requested_level BETWEEN 1 AND 10),
  status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','returned','rejected')),
  reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL,
  decision_note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  decided_at TIMESTAMPTZ
);

-- مستويات الموظفين وتقييم الأداء: لا تمنح هذه المستويات صلاحيات إدارية تلقائياً.
CREATE TABLE IF NOT EXISTS staff_level_rules (
  level_no SMALLINT PRIMARY KEY CHECK (level_no BETWEEN 1 AND 10),
  level_name VARCHAR(100) NOT NULL,
  benefit_description TEXT NOT NULL
);
INSERT INTO staff_level_rules(level_no,level_name,benefit_description) VALUES
(1,'متدرب','تعريف بالمهام'),(2,'مساعد','أدوات تنظيم إضافية'),(3,'مشارك','إسناد مهام محددة'),
(4,'منسق','تنظيم سير العمل'),(5,'متمرس','إحصاءات أداء شخصية'),(6,'متقدم','إدارة مهام فرعية ضمن الصلاحية'),
(7,'خبير','مراجعة أعمال القسم'),(8,'مستشار','اقتراح تحسينات إدارية'),(9,'خبير أول','أولوية في برامج التدريب'),(10,'قيادي','تكريم وظيفي دون تجاوز صلاحيات المالك')
ON CONFLICT(level_no) DO NOTHING;

CREATE TABLE IF NOT EXISTS staff_performance_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  department_id BIGINT REFERENCES departments(id) ON DELETE SET NULL,
  reviewer_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  level_no SMALLINT NOT NULL CHECK (level_no BETWEEN 1 AND 10),
  score NUMERIC(5,2) CHECK (score BETWEEN 0 AND 100),
  review_period DATERANGE,
  strengths TEXT,
  improvement_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_staff_reviews_user_time ON staff_performance_reviews(staff_user_id, created_at DESC);

-- البلاغات والقرارات والاستئناف.
CREATE TABLE IF NOT EXISTS moderation_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  target_kind VARCHAR(24) NOT NULL CHECK (target_kind IN ('user','post','group','channel','book','research','other')),
  target_id TEXT NOT NULL,
  violation_kind VARCHAR(64) NOT NULL,
  severity VARCHAR(16) NOT NULL DEFAULT 'normal' CHECK (severity IN ('low','normal','high','critical')),
  description TEXT,
  evidence JSONB NOT NULL DEFAULT '[]'::jsonb,
  status VARCHAR(24) NOT NULL DEFAULT 'received' CHECK (status IN ('received','reviewing','assigned','decided','dismissed','appealed','closed')),
  assigned_to UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_moderation_reports_status ON moderation_reports(status,severity,created_at DESC);

CREATE TABLE IF NOT EXISTS moderation_decisions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id UUID NOT NULL REFERENCES moderation_reports(id) ON DELETE CASCADE,
  decision_kind VARCHAR(24) NOT NULL CHECK (decision_kind IN ('warning','notice','restrict','temporary_ban','permanent_ban','dismiss')),
  reason TEXT NOT NULL,
  issued_by UUID REFERENCES users(id) ON DELETE SET NULL,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS moderation_appeals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  decision_id UUID NOT NULL REFERENCES moderation_decisions(id) ON DELETE CASCADE,
  appellant_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  appeal_text TEXT NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted','rejected','returned')),
  reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL,
  decision_note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  decided_at TIMESTAMPTZ
);

-- النسخ الاحتياطي: سياسات وجدولة وبيانات تنفيذ؛ التخزين الفعلي خدمة خارجية مشفرة.
CREATE TABLE IF NOT EXISTS backup_policies (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  policy_name VARCHAR(120) NOT NULL UNIQUE,
  cadence VARCHAR(16) NOT NULL CHECK (cadence IN ('daily','weekly','monthly','manual')),
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  retention_count INTEGER NOT NULL DEFAULT 5 CHECK (retention_count > 0),
  encryption_required BOOLEAN NOT NULL DEFAULT TRUE,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
INSERT INTO backup_policies(policy_name,cadence,retention_count) VALUES
('نسخة يومية','daily',14),('نسخة أسبوعية','weekly',8),('نسخة شهرية','monthly',12),('نسخة يدوية','manual',10)
ON CONFLICT(policy_name) DO NOTHING;

CREATE TABLE IF NOT EXISTS backup_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  policy_id BIGINT REFERENCES backup_policies(id) ON DELETE SET NULL,
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ,
  status VARCHAR(20) NOT NULL DEFAULT 'queued' CHECK (status IN ('queued','running','succeeded','failed','verified','restore_requested','restored')),
  storage_object_key TEXT,
  checksum_sha256 CHAR(64),
  encrypted BOOLEAN NOT NULL DEFAULT TRUE,
  byte_size BIGINT CHECK (byte_size IS NULL OR byte_size >= 0),
  initiated_by UUID REFERENCES users(id) ON DELETE SET NULL,
  result_note TEXT
);
CREATE INDEX IF NOT EXISTS idx_backup_runs_recent ON backup_runs(started_at DESC);

-- توثيق كل إجراء إداري مهم يبقى ضمن audit_logs الموجود في المخطط الأساسي.
CREATE INDEX IF NOT EXISTS idx_calendar_events_status_date ON calendar_events(publication_status,starts_at);


-- أدوار المنصة وصلاحياتها الأساسية. توزيع الصلاحيات الفعلي يتم عبر API مع التحقق من المالك.
INSERT INTO roles(code,name,description) VALUES
('researcher','باحث علمي','إدارة البحوث والملاحظات وفق صلاحيات الحساب'),
('contributor','مساهم','اقتراح كتب وبيانات علمية للمراجعة قبل النشر'),
('moderator','مشرف','مراجعة محتوى ضمن نطاق محدد'),
('reviewer','مراجع علمي','مراجعة علمية أو فنية أو حقوقية'),
('support_staff','موظف دعم','معالجة طلبات الدعم المسندة إليه')
ON CONFLICT(code) DO NOTHING;
INSERT INTO permissions(code,description) VALUES
('catalog.read','قراءة فهرس المكتبة'),('catalog.propose','اقتراح سجل كتاب'),('catalog.review','مراجعة بيانات الفهرس'),
('research.manage_own','إدارة البحوث الشخصية'),('research.review','مراجعة البحوث المسندة'),
('community.moderate','إدارة المحتوى ضمن النطاق'),('community.approve','اعتماد إنشاء مجموعة أو قناة'),
('members.manage_limited','إدارة أعضاء ضمن صلاحية محددة'),('reports.review','مراجعة البلاغات المسندة'),
('staff.assign','إسناد مهام الموظفين'),('departments.create','إنشاء أقسام إدارية'),
('backups.manage','إدارة النسخ الاحتياطية'),('security.audit.read','قراءة السجل الأمني'),
('owner.settings.manage','إدارة إعدادات المالك')
ON CONFLICT(code) DO NOTHING;

-- معرّف 313 محجوز للمالك حصراً. يُفرض هذا القيد عند إنشاء الحساب أو تحديثه.
CREATE OR REPLACE FUNCTION enforce_qayyum_owner_public_id() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.public_id = '313' AND NEW.account_type <> 'owner' THEN
    RAISE EXCEPTION 'Public ID 313 is reserved for the platform owner';
  END IF;
  IF NEW.account_type = 'owner' AND NEW.public_id IS DISTINCT FROM '313' THEN
    RAISE EXCEPTION 'The platform owner account must use public ID 313';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_qayyum_owner_public_id ON users;
CREATE TRIGGER trg_qayyum_owner_public_id BEFORE INSERT OR UPDATE OF public_id, account_type ON users
FOR EACH ROW EXECUTE FUNCTION enforce_qayyum_owner_public_id();

-- بناء مجموعات كتب خاصة بالمستخدم، فوق سجل القراءة والعلامات والملاحظات الموجود.
CREATE TABLE IF NOT EXISTS user_book_collections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR(220) NOT NULL,
  description TEXT,
  visibility VARCHAR(16) NOT NULL DEFAULT 'private' CHECK (visibility IN ('private','shared')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS user_book_collection_items (
  collection_id UUID NOT NULL REFERENCES user_book_collections(id) ON DELETE CASCADE,
  work_id UUID NOT NULL REFERENCES works(id) ON DELETE CASCADE,
  added_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY(collection_id,work_id)
);

-- ترجمة عناصر الواجهة والمحتوى المترجم مع الاحتفاظ بالنص الأصلي.
CREATE TABLE IF NOT EXISTS localized_content (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  entity_kind VARCHAR(48) NOT NULL,
  entity_id TEXT NOT NULL,
  language_code VARCHAR(32) NOT NULL,
  field_key VARCHAR(80) NOT NULL,
  translated_text TEXT NOT NULL,
  translator_name VARCHAR(240),
  review_status VARCHAR(24) NOT NULL DEFAULT 'needs_review' CHECK (review_status IN ('needs_review','approved','rejected')),
  reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(entity_kind,entity_id,language_code,field_key)
);

-- تعدد طرق عرض تاريخ المناسبة، مع توثيق المرجع وعدم استبدال التاريخ الأصلي.
ALTER TABLE calendar_events ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE calendar_events ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ;
ALTER TABLE calendar_events ADD COLUMN IF NOT EXISTS calendar_method VARCHAR(80);
CREATE TABLE IF NOT EXISTS calendar_event_date_variants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES calendar_events(id) ON DELETE CASCADE,
  authority_label VARCHAR(220) NOT NULL,
  hijri_date_label VARCHAR(80) NOT NULL,
  gregorian_date DATE,
  source_id UUID REFERENCES sources(id) ON DELETE SET NULL,
  note TEXT,
  review_status VARCHAR(24) NOT NULL DEFAULT 'needs_review' CHECK (review_status IN ('needs_review','approved','disputed')),
  UNIQUE(event_id,authority_label,hijri_date_label)
);

-- لا توجد رسائل خاصة بين الأعضاء في تصميم القيّوم المعتمد؛ التواصل العام يكون عبر المجموعات والقنوات والدعم.
DROP TABLE IF EXISTS direct_messages CASCADE;
DROP TABLE IF EXISTS direct_conversation_members CASCADE;
DROP TABLE IF EXISTS direct_conversations CASCADE;

COMMIT;
