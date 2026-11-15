-- مكتبة القيّوم | سجل مصادر الفهرسة ودفعات الاستيراد
-- PostgreSQL 16+ | يُنفّذ بعد 001_core_schema.sql و002_platform_modules.sql
BEGIN;
SET search_path TO qayyum, public;

-- سجل موحّد لمصادر الفهرسة الخارجية، منفصل عن سجل المصادر الببليوغرافية لكل عمل.
CREATE TABLE IF NOT EXISTS catalog_sources (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_code VARCHAR(40) NOT NULL UNIQUE,
    source_name VARCHAR(240) NOT NULL,
    base_url TEXT NOT NULL,
    content_scope TEXT,
    access_method TEXT,
    rights_policy TEXT,
    scale_note TEXT,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS catalog_import_batches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id BIGINT REFERENCES catalog_sources(id) ON DELETE RESTRICT,
    batch_name VARCHAR(240) NOT NULL,
    input_filename VARCHAR(500),
    input_sha256 CHAR(64),
    status VARCHAR(24) NOT NULL DEFAULT 'received'
      CHECK (status IN ('received','validating','needs_review','approved','imported','rejected','failed')),
    records_seen INTEGER NOT NULL DEFAULT 0 CHECK (records_seen >= 0),
    records_valid INTEGER NOT NULL DEFAULT 0 CHECK (records_valid >= 0),
    records_rejected INTEGER NOT NULL DEFAULT 0 CHECK (records_rejected >= 0),
    records_duplicate INTEGER NOT NULL DEFAULT 0 CHECK (records_duplicate >= 0),
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ,
    notes TEXT
);

-- تحفظ السجلات الخام قبل تحويلها إلى works/editions؛ لا نشر تلقائي.
CREATE TABLE IF NOT EXISTS catalog_import_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_id UUID NOT NULL REFERENCES catalog_import_batches(id) ON DELETE CASCADE,
    source_id BIGINT NOT NULL REFERENCES catalog_sources(id) ON DELETE RESTRICT,
    source_record_id VARCHAR(500) NOT NULL,
    source_record_url TEXT,
    raw_record JSONB NOT NULL,
    normalized_title TEXT,
    normalized_author TEXT,
    proposed_school_family VARCHAR(40),
    verification_status VARCHAR(24) NOT NULL DEFAULT 'unverified'
      CHECK (verification_status IN ('verified','needs_review','unverified','rejected')),
    duplicate_of UUID REFERENCES catalog_import_records(id) ON DELETE SET NULL,
    validation_errors JSONB NOT NULL DEFAULT '[]'::jsonb,
    reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    imported_work_id UUID REFERENCES works(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(source_id, source_record_id)
);

CREATE INDEX IF NOT EXISTS idx_catalog_import_records_batch ON catalog_import_records(batch_id);
CREATE INDEX IF NOT EXISTS idx_catalog_import_records_status ON catalog_import_records(verification_status);
CREATE INDEX IF NOT EXISTS idx_catalog_import_records_title_author ON catalog_import_records(normalized_title, normalized_author);
CREATE INDEX IF NOT EXISTS idx_catalog_import_records_raw_gin ON catalog_import_records USING GIN(raw_record);
CREATE INDEX IF NOT EXISTS idx_catalog_sources_enabled ON catalog_sources(enabled) WHERE enabled = TRUE;

INSERT INTO catalog_sources
(source_code, source_name, base_url, content_scope, access_method, rights_policy, scale_note)
VALUES
('SRC001','OpenITI / KITAB','https://kitab-project.org/data/download','نصوص تراثية وبيانات مؤلفين وأعمال','مستودعات وتنزيلات موثقة','فحص ترخيص كل إصدار وملف؛ لا يُفترض السماح بإعادة الاستضافة','الإصدار الموصوف في الحزمة نحو 6,236 عملاً متميزاً'),
('SRC002','Al-Furqan E-Database','https://digitallibrary.al-furqan.com/','فهرسة مخطوطات ومجموعات ومعلومات ببليوغرافية','بحث وفهرسة عبر الموقع؛ التنزيل الجماعي غير مثبت','بيانات الفهرسة لا تعني حق نشر صور المخطوطات','أعداد سجلات المخطوطات لا تساوي كتباً كاملة'),
('SRC003','Internet Archive','https://archive.org/developers/','بيانات وصفية ونسخ رقمية وOCR بحسب العنصر','واجهات API وبيانات العناصر','تحقق من حقوق كل عنصر وشروط تنزيله','البحث يُجزّأ إلى استعلامات وصفحات'),
('SRC004','Maktaba Shamela','https://shamela.amuslim.org/download.php','نصوص وكتب إسلامية','حزم تنزيل؛ يلزم فحص البنية','مراجعة حقوق كل كتاب ومصدره قبل إعادة الاستضافة','أعداد الحزم ليست بالضرورة عناوين فريدة'),
('SRC005','HathiTrust Digital Library','https://www.hathitrust.org/','بيانات ببليوغرافية ونسخ رقمية بحسب الإتاحة','واجهات API وOAI وفق الشروط','حقوق الوصول والتنزيل تختلف لكل عنصر','مصدر إثراء ببليوغرافي وليس فهرساً إسلامياً حصرياً'),
('SRC006','University of Michigan Islamic Manuscripts Guide','https://guides.lib.umich.edu/islamicmss/digitized','دليل مجموعات مخطوطات وروابط فهارس','روابط إلى مجموعات وواجهات خارجية','تطبق حقوق كل مكتبة وعنصر','دليل اكتشاف وليس قاعدة كتب شاملة'),
('SRC007','Open Library','https://openlibrary.org/developers/api','بيانات عناوين وطبعات ومؤلفين','واجهات بحث وبيانات API','تحقق من شروط API وحقوق الصور والملفات','يستخدم للإثراء والمطابقة لا لإثبات الانتماء المذهبي')
ON CONFLICT (source_code) DO UPDATE SET
 source_name=EXCLUDED.source_name, base_url=EXCLUDED.base_url,
 content_scope=EXCLUDED.content_scope, access_method=EXCLUDED.access_method,
 rights_policy=EXCLUDED.rights_policy, scale_note=EXCLUDED.scale_note;

COMMIT;
