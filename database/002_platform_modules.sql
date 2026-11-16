-- مكتبة القيّوم | الوحدات الإضافية للمنصة
-- PostgreSQL 16+ | يُشغّل بعد 001_core_schema.sql
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
SET search_path TO qayyum, public;

-- الروايات والرواة والأسانيد: لا تُدمج الطرق أو أحكام العلماء تلقائياً
CREATE TABLE narrators (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  canonical_name VARCHAR(300) NOT NULL,
  biography TEXT,
  identity_status VARCHAR(24) NOT NULL DEFAULT 'unverified'
    CHECK (identity_status IN ('verified','under_review','disputed','unverified')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE narrator_names (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  narrator_id UUID NOT NULL REFERENCES narrators(id) ON DELETE CASCADE,
  name VARCHAR(300) NOT NULL,
  name_kind VARCHAR(32) NOT NULL DEFAULT 'alternate'
);
CREATE TABLE hadith_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  canonical_text TEXT NOT NULL,
  topic_tags TEXT[] NOT NULL DEFAULT '{}',
  text_status VARCHAR(24) NOT NULL DEFAULT 'needs_review'
    CHECK (text_status IN ('verified','variant','needs_review','disputed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE hadith_variants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id UUID NOT NULL REFERENCES hadith_reports(id) ON DELETE CASCADE,
  wording TEXT NOT NULL,
  source_id UUID REFERENCES sources(id) ON DELETE SET NULL,
  edition_id UUID REFERENCES editions(id) ON DELETE SET NULL,
  volume_label VARCHAR(80), page_label VARCHAR(80), hadith_number VARCHAR(80),
  verification_status VARCHAR(24) NOT NULL DEFAULT 'unverified'
    CHECK (verification_status IN ('verified','unverified','disputed','incomplete'))
);
CREATE TABLE isnads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  variant_id UUID NOT NULL REFERENCES hadith_variants(id) ON DELETE CASCADE,
  source_id UUID REFERENCES sources(id) ON DELETE SET NULL,
  edition_id UUID REFERENCES editions(id) ON DELETE SET NULL,
  chain_note TEXT,
  route_label VARCHAR(200)
);
CREATE TABLE isnad_links (
  isnad_id UUID NOT NULL REFERENCES isnads(id) ON DELETE CASCADE,
  sequence_no INTEGER NOT NULL CHECK (sequence_no > 0),
  narrator_id UUID NOT NULL REFERENCES narrators(id) ON DELETE RESTRICT,
  transmission_wording VARCHAR(120),
  PRIMARY KEY(isnad_id, sequence_no)
);
CREATE TABLE narrator_assessments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  narrator_id UUID NOT NULL REFERENCES narrators(id) ON DELETE CASCADE,
  scholar_name VARCHAR(300) NOT NULL,
  school_id BIGINT REFERENCES schools(id) ON DELETE SET NULL,
  assessment_text TEXT NOT NULL,
  source_id UUID REFERENCES sources(id) ON DELETE SET NULL,
  edition_id UUID REFERENCES editions(id) ON DELETE SET NULL,
  volume_label VARCHAR(80), page_label VARCHAR(80),
  assessment_status VARCHAR(24) NOT NULL DEFAULT 'needs_review'
    CHECK (assessment_status IN ('verified','needs_review','disputed'))
);
CREATE TABLE hadith_grades (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id UUID NOT NULL REFERENCES hadith_reports(id) ON DELETE CASCADE,
  variant_id UUID REFERENCES hadith_variants(id) ON DELETE CASCADE,
  scholar_name VARCHAR(300) NOT NULL,
  school_id BIGINT REFERENCES schools(id) ON DELETE SET NULL,
  grade_label VARCHAR(120) NOT NULL,
  explanation TEXT,
  source_id UUID REFERENCES sources(id) ON DELETE SET NULL,
  edition_id UUID REFERENCES editions(id) ON DELETE SET NULL,
  volume_label VARCHAR(80), page_label VARCHAR(80),
  verification_status VARCHAR(24) NOT NULL DEFAULT 'unverified'
    CHECK (verification_status IN ('verified','unverified','disputed'))
);

-- القراءة والملاحظات والمختارات العلمية
CREATE TABLE reading_progress (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  edition_id UUID NOT NULL REFERENCES editions(id) ON DELETE CASCADE,
  current_page INTEGER CHECK (current_page IS NULL OR current_page > 0),
  progress_percent NUMERIC(5,2) CHECK (progress_percent BETWEEN 0 AND 100),
  last_opened_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY(user_id, edition_id)
);
CREATE TABLE bookmarks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  edition_id UUID REFERENCES editions(id) ON DELETE CASCADE,
  page_label VARCHAR(80), title VARCHAR(240), note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE annotations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  edition_id UUID NOT NULL REFERENCES editions(id) ON DELETE CASCADE,
  page_label VARCHAR(80), selected_text TEXT,
  annotation_kind VARCHAR(24) NOT NULL DEFAULT 'note'
    CHECK (annotation_kind IN ('highlight','underline','strike','note','quote')),
  color_code VARCHAR(24), body TEXT,
  visibility VARCHAR(16) NOT NULL DEFAULT 'private'
    CHECK (visibility IN ('private','shared')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE research_projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR(400) NOT NULL,
  description TEXT,
  project_kind VARCHAR(32) NOT NULL DEFAULT 'research'
    CHECK (project_kind IN ('research','debate','study','reading_plan','other')),
  visibility VARCHAR(16) NOT NULL DEFAULT 'private'
    CHECK (visibility IN ('private','group','public')),
  status VARCHAR(24) NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','active','review','completed','archived')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE research_sections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES research_projects(id) ON DELETE CASCADE,
  parent_id UUID REFERENCES research_sections(id) ON DELETE CASCADE,
  title VARCHAR(400) NOT NULL,
  body TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE research_evidence (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES research_projects(id) ON DELETE CASCADE,
  section_id UUID REFERENCES research_sections(id) ON DELETE SET NULL,
  evidence_kind VARCHAR(24) NOT NULL
    CHECK (evidence_kind IN ('quran','hadith','rational','historical','linguistic','quote','other')),
  content TEXT NOT NULL,
  source_id UUID REFERENCES sources(id) ON DELETE SET NULL,
  edition_id UUID REFERENCES editions(id) ON DELETE SET NULL,
  volume_label VARCHAR(80), page_label VARCHAR(80),
  verification_status VARCHAR(24) NOT NULL DEFAULT 'needs_review'
    CHECK (verification_status IN ('verified','needs_review','external_unverified','disputed')),
  source_note TEXT
);
CREATE TABLE research_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES research_projects(id) ON DELETE CASCADE,
  version_no INTEGER NOT NULL,
  snapshot JSONB NOT NULL,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(project_id, version_no)
);

-- الذاكرة العلمية خاصة بكل مستخدم وقابلة للإيقاف
CREATE TABLE user_scientific_memory_settings (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  retention_days INTEGER CHECK (retention_days IS NULL OR retention_days > 0),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE user_scientific_memories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  memory_kind VARCHAR(32) NOT NULL
    CHECK (memory_kind IN ('study_progress','preference','unresolved_question','project_context','term_explained','reading_interest')),
  title VARCHAR(300) NOT NULL,
  memory_content JSONB NOT NULL,
  source_project_id UUID REFERENCES research_projects(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- المجموعات والقنوات والرسائل
CREATE TABLE community_spaces (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  space_kind VARCHAR(16) NOT NULL CHECK (space_kind IN ('group','channel')),
  name VARCHAR(240) NOT NULL,
  slug VARCHAR(260) UNIQUE,
  description TEXT,
  privacy VARCHAR(16) NOT NULL DEFAULT 'public' CHECK (privacy IN ('public','private')),
  moderation_level SMALLINT NOT NULL DEFAULT 2 CHECK (moderation_level BETWEEN 1 AND 3),
  status VARCHAR(24) NOT NULL DEFAULT 'pending_owner_review'
    CHECK (status IN ('pending_owner_review','active','paused','rejected','archived')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE community_members (
  space_id UUID NOT NULL REFERENCES community_spaces(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  member_role VARCHAR(24) NOT NULL DEFAULT 'member'
    CHECK (member_role IN ('member','moderator','manager')),
  membership_status VARCHAR(24) NOT NULL DEFAULT 'active'
    CHECK (membership_status IN ('active','muted','banned','left','pending')),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY(space_id, user_id)
);
CREATE TABLE community_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  space_id UUID NOT NULL REFERENCES community_spaces(id) ON DELETE CASCADE,
  author_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  parent_post_id UUID REFERENCES community_posts(id) ON DELETE CASCADE,
  body TEXT NOT NULL,
  moderation_status VARCHAR(24) NOT NULL DEFAULT 'pending'
    CHECK (moderation_status IN ('pending','visible','held','removed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- لا تُنشأ جداول رسائل خاصة؛ التواصل العام فقط عبر المجموعات والقنوات والدعم.

-- المتابعة والتقييمات والشارات والتوثيق
CREATE TABLE follows (
  follower_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  target_kind VARCHAR(24) NOT NULL CHECK (target_kind IN ('user','work','author','space','discipline','school')),
  target_id TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY(follower_user_id, target_kind, target_id)
);
CREATE TABLE work_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  work_id UUID NOT NULL REFERENCES works(id) ON DELETE CASCADE,
  edition_id UUID REFERENCES editions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  review_text TEXT,
  moderation_status VARCHAR(20) NOT NULL DEFAULT 'visible'
    CHECK (moderation_status IN ('visible','reported','hidden')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, work_id, edition_id)
);
CREATE TABLE badge_definitions (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code VARCHAR(80) NOT NULL UNIQUE,
  name VARCHAR(180) NOT NULL,
  description TEXT NOT NULL
);
CREATE TABLE user_badges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  badge_id BIGINT NOT NULL REFERENCES badge_definitions(id) ON DELETE RESTRICT,
  status VARCHAR(24) NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','active','expired','suspended','revoked','rejected')),
  granted_by UUID REFERENCES users(id) ON DELETE SET NULL,
  valid_until DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE verification_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  applicant_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subject_kind VARCHAR(24) NOT NULL,
  subject_label VARCHAR(300) NOT NULL,
  nominated_by UUID REFERENCES users(id) ON DELETE SET NULL,
  subject_consent_at TIMESTAMPTZ,
  status VARCHAR(24) NOT NULL DEFAULT 'awaiting_consent'
    CHECK (status IN ('awaiting_consent','submitted','under_review','approved','rejected','appealed','expired')),
  evidence JSONB NOT NULL DEFAULT '[]'::jsonb,
  reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- التقويم والإشعارات والدعم والإدارة
CREATE TABLE calendar_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR(300) NOT NULL,
  description TEXT,
  event_kind VARCHAR(32) NOT NULL,
  starts_at TIMESTAMPTZ,
  ends_at TIMESTAMPTZ,
  hijri_date_label VARCHAR(80),
  date_variation_note TEXT,
  school_id BIGINT REFERENCES schools(id) ON DELETE SET NULL,
  source_id UUID REFERENCES sources(id) ON DELETE SET NULL,
  publication_status VARCHAR(20) NOT NULL DEFAULT 'draft'
    CHECK (publication_status IN ('draft','pending','published','withdrawn'))
);
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  notification_kind VARCHAR(40) NOT NULL,
  priority VARCHAR(12) NOT NULL DEFAULT 'normal' CHECK (priority IN ('normal','important','urgent')),
  title VARCHAR(300) NOT NULL,
  body TEXT,
  target_url TEXT,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE support_tickets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_no BIGINT GENERATED ALWAYS AS IDENTITY UNIQUE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  assigned_to UUID REFERENCES users(id) ON DELETE SET NULL,
  category VARCHAR(32) NOT NULL,
  priority VARCHAR(12) NOT NULL DEFAULT 'normal' CHECK (priority IN ('normal','important','urgent')),
  status VARCHAR(24) NOT NULL DEFAULT 'received'
    CHECK (status IN ('received','reviewing','assigned','in_progress','waiting_user','resolved','closed','appealed')),
  subject VARCHAR(300) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE support_ticket_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id UUID NOT NULL REFERENCES support_tickets(id) ON DELETE CASCADE,
  sender_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE departments (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  parent_id BIGINT REFERENCES departments(id) ON DELETE SET NULL,
  name VARCHAR(200) NOT NULL,
  description TEXT,
  status VARCHAR(16) NOT NULL DEFAULT 'active' CHECK (status IN ('active','paused','archived'))
);
CREATE TABLE department_assignments (
  department_id BIGINT NOT NULL REFERENCES departments(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  assignment_role VARCHAR(24) NOT NULL CHECK (assignment_role IN ('manager','deputy','staff','reviewer')),
  granted_by UUID REFERENCES users(id) ON DELETE SET NULL,
  PRIMARY KEY(department_id, user_id, assignment_role)
);
CREATE TABLE owner_approval_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  submitted_by UUID REFERENCES users(id) ON DELETE SET NULL,
  request_kind VARCHAR(40) NOT NULL,
  target_kind VARCHAR(40) NOT NULL,
  target_id TEXT NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','approved','returned','rejected')),
  decision_by UUID REFERENCES users(id) ON DELETE SET NULL,
  decision_note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), decided_at TIMESTAMPTZ
);

-- فهارس للأحجام الكبيرة والاستعلامات المتكررة
CREATE INDEX idx_hadith_text_search ON hadith_reports USING gin(to_tsvector('simple', canonical_text));
CREATE INDEX idx_narrators_name_search ON narrators USING gin(to_tsvector('simple', canonical_name));
CREATE INDEX idx_reading_user_recent ON reading_progress(user_id, last_opened_at DESC);
CREATE INDEX idx_annotations_user_edition ON annotations(user_id, edition_id);
CREATE INDEX idx_research_owner_status ON research_projects(owner_user_id, status, updated_at DESC);
CREATE INDEX idx_memory_user_kind ON user_scientific_memories(user_id, memory_kind);
CREATE INDEX idx_community_space_posts ON community_posts(space_id, created_at DESC);
CREATE INDEX idx_notifications_unread ON notifications(user_id, created_at DESC) WHERE read_at IS NULL;
CREATE INDEX idx_support_status_priority ON support_tickets(status, priority, created_at DESC);
CREATE INDEX idx_approval_queue_pending ON owner_approval_queue(created_at) WHERE status = 'pending';

COMMIT;
