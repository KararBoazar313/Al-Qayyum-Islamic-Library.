-- مكتبة القيّوم | مخطط قاعدة البيانات الأولي
-- PostgreSQL 16+
-- هذا ملف تأسيسي قابل للمراجعة والتطوير، وليس قاعدة بيانات منشورة أو مشغّلة.

BEGIN;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE SCHEMA IF NOT EXISTS qayyum;
SET search_path TO qayyum, public;

-- الحسابات والهوية
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    public_id VARCHAR(12) UNIQUE,
    account_type VARCHAR(20) NOT NULL DEFAULT 'member'
        CHECK (account_type IN ('owner','admin','member')),
    status VARCHAR(20) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','suspended','banned','pending_deletion')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE user_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    display_name VARCHAR(160),
    username VARCHAR(64) UNIQUE,
    biography TEXT,
    preferred_language VARCHAR(16) NOT NULL DEFAULT 'ar',
    timezone VARCHAR(64),
    avatar_object_key TEXT,
    cover_object_key TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE auth_identities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider VARCHAR(24) NOT NULL CHECK (provider IN ('password','google','email','phone')),
    provider_subject VARCHAR(255) NOT NULL,
    credential_hash TEXT,
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(provider, provider_subject)
);

CREATE TABLE roles (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code VARCHAR(64) NOT NULL UNIQUE,
    name VARCHAR(120) NOT NULL,
    description TEXT
);

CREATE TABLE permissions (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code VARCHAR(100) NOT NULL UNIQUE,
    description TEXT
);

CREATE TABLE user_roles (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id BIGINT NOT NULL REFERENCES roles(id) ON DELETE RESTRICT,
    granted_by UUID REFERENCES users(id) ON DELETE SET NULL,
    granted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY(user_id, role_id)
);

CREATE TABLE role_permissions (
    role_id BIGINT NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission_id BIGINT NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    PRIMARY KEY(role_id, permission_id)
);

-- التصنيف العلمي والمدارس
CREATE TABLE schools (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    parent_id BIGINT REFERENCES schools(id) ON DELETE RESTRICT,
    code VARCHAR(80) NOT NULL UNIQUE,
    name VARCHAR(200) NOT NULL,
    school_kind VARCHAR(32) NOT NULL
        CHECK (school_kind IN ('madhhab','fiqh','kalam','hadith','intellectual_tradition','other')),
    description TEXT
);

CREATE TABLE disciplines (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    parent_id BIGINT REFERENCES disciplines(id) ON DELETE RESTRICT,
    name VARCHAR(200) NOT NULL,
    slug VARCHAR(220) NOT NULL UNIQUE,
    description TEXT
);

CREATE TABLE categories (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    parent_id BIGINT REFERENCES categories(id) ON DELETE RESTRICT,
    name VARCHAR(200) NOT NULL,
    slug VARCHAR(220) NOT NULL UNIQUE
);

CREATE TABLE work_types (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code VARCHAR(80) NOT NULL UNIQUE,
    name VARCHAR(160) NOT NULL
);

-- المؤلفون والأعمال والطبعات
CREATE TABLE authors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    canonical_name VARCHAR(300) NOT NULL,
    birth_year_text VARCHAR(40),
    death_year_text VARCHAR(40),
    biography TEXT,
    identity_status VARCHAR(24) NOT NULL DEFAULT 'unverified'
        CHECK (identity_status IN ('verified','under_review','disputed','unverified')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE author_names (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    author_id UUID NOT NULL REFERENCES authors(id) ON DELETE CASCADE,
    name VARCHAR(300) NOT NULL,
    name_kind VARCHAR(32) NOT NULL DEFAULT 'alternate'
        CHECK (name_kind IN ('birth','kunya','laqab','nisba','alternate','transliteration'))
);

CREATE TABLE works (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    canonical_title VARCHAR(500) NOT NULL,
    original_title VARCHAR(500),
    description TEXT,
    language_code VARCHAR(16),
    composition_date_text VARCHAR(100),
    attribution_status VARCHAR(24) NOT NULL DEFAULT 'unverified'
        CHECK (attribution_status IN ('verified','attributed','disputed','anonymous','unverified')),
    publication_status VARCHAR(24) NOT NULL DEFAULT 'draft'
        CHECK (publication_status IN ('draft','in_review','approved','rejected','withdrawn')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE work_authors (
    work_id UUID NOT NULL REFERENCES works(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES authors(id) ON DELETE RESTRICT,
    author_order SMALLINT NOT NULL DEFAULT 1,
    contribution VARCHAR(40) NOT NULL DEFAULT 'author',
    attribution_note TEXT,
    PRIMARY KEY(work_id, author_id, contribution)
);

CREATE TABLE publishers (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(300) NOT NULL,
    country_code CHAR(2),
    website TEXT
);

CREATE TABLE editions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    work_id UUID NOT NULL REFERENCES works(id) ON DELETE CASCADE,
    publisher_id BIGINT REFERENCES publishers(id) ON DELETE SET NULL,
    edition_title VARCHAR(500),
    editor_name VARCHAR(300),
    edition_number VARCHAR(80),
    publication_year_text VARCHAR(40),
    volume_count INTEGER CHECK (volume_count IS NULL OR volume_count > 0),
    page_count INTEGER CHECK (page_count IS NULL OR page_count > 0),
    isbn VARCHAR(32),
    edition_language VARCHAR(16),
    review_status VARCHAR(24) NOT NULL DEFAULT 'pending'
        CHECK (review_status IN ('pending','technical_review','scientific_review','approved','rejected')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE work_schools (
    work_id UUID NOT NULL REFERENCES works(id) ON DELETE CASCADE,
    school_id BIGINT NOT NULL REFERENCES schools(id) ON DELETE RESTRICT,
    relation_note TEXT,
    evidence_status VARCHAR(24) NOT NULL DEFAULT 'needs_review'
        CHECK (evidence_status IN ('verified','needs_review','disputed')),
    PRIMARY KEY(work_id, school_id)
);

CREATE TABLE work_categories (
    work_id UUID NOT NULL REFERENCES works(id) ON DELETE CASCADE,
    category_id BIGINT NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
    PRIMARY KEY(work_id, category_id)
);

CREATE TABLE work_disciplines (
    work_id UUID NOT NULL REFERENCES works(id) ON DELETE CASCADE,
    discipline_id BIGINT NOT NULL REFERENCES disciplines(id) ON DELETE RESTRICT,
    PRIMARY KEY(work_id, discipline_id)
);

CREATE TABLE work_type_links (
    work_id UUID NOT NULL REFERENCES works(id) ON DELETE CASCADE,
    work_type_id BIGINT NOT NULL REFERENCES work_types(id) ON DELETE RESTRICT,
    PRIMARY KEY(work_id, work_type_id)
);

-- المصادر والملفات وحقوق النشر
CREATE TABLE sources (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(500) NOT NULL,
    source_type VARCHAR(40) NOT NULL,
    url TEXT,
    bibliographic_citation TEXT,
    reliability_note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE work_sources (
    work_id UUID NOT NULL REFERENCES works(id) ON DELETE CASCADE,
    source_id UUID NOT NULL REFERENCES sources(id) ON DELETE RESTRICT,
    relation_note TEXT,
    PRIMARY KEY(work_id, source_id)
);

CREATE TABLE digital_files (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    edition_id UUID REFERENCES editions(id) ON DELETE CASCADE,
    object_key TEXT NOT NULL UNIQUE,
    original_filename VARCHAR(500),
    mime_type VARCHAR(160) NOT NULL,
    file_size_bytes BIGINT CHECK (file_size_bytes IS NULL OR file_size_bytes >= 0),
    checksum_sha256 CHAR(64),
    file_role VARCHAR(32) NOT NULL DEFAULT 'full_text'
        CHECK (file_role IN ('full_text','scan','manuscript','cover','audio','video','ocr_text','supplement')),
    technical_status VARCHAR(24) NOT NULL DEFAULT 'pending'
        CHECK (technical_status IN ('pending','scanning','clean','rejected','corrupt')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE file_rights (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    file_id UUID NOT NULL REFERENCES digital_files(id) ON DELETE CASCADE,
    rights_status VARCHAR(40) NOT NULL
        CHECK (rights_status IN ('public_domain','licensed_distribution','reading_only','special_permission','unknown_review','prohibited')),
    rights_holder VARCHAR(300),
    evidence_source TEXT,
    permission_expires_at DATE,
    notes TEXT,
    reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ
);

-- سجل المراجعات والتدقيق
CREATE TABLE review_tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    target_kind VARCHAR(40) NOT NULL,
    target_id UUID NOT NULL,
    review_kind VARCHAR(24) NOT NULL CHECK (review_kind IN ('technical','scientific','rights')),
    status VARCHAR(24) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending','assigned','in_progress','approved','rejected','returned')),
    assigned_to UUID REFERENCES users(id) ON DELETE SET NULL,
    decision_note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ
);

CREATE TABLE audit_logs (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    actor_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action_code VARCHAR(100) NOT NULL,
    target_kind VARCHAR(64),
    target_id TEXT,
    details JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- فهارس أساسية للبحث والربط
CREATE INDEX idx_works_title ON works USING gin (to_tsvector('simple', coalesce(canonical_title,'')));
CREATE INDEX idx_authors_name ON authors USING gin (to_tsvector('simple', coalesce(canonical_name,'')));
CREATE INDEX idx_editions_work ON editions(work_id);
CREATE INDEX idx_work_authors_author ON work_authors(author_id);
CREATE INDEX idx_work_schools_school ON work_schools(school_id);
CREATE INDEX idx_files_edition ON digital_files(edition_id);
CREATE INDEX idx_files_checksum ON digital_files(checksum_sha256) WHERE checksum_sha256 IS NOT NULL;
CREATE INDEX idx_audit_logs_actor_time ON audit_logs(actor_user_id, created_at DESC);
CREATE INDEX idx_audit_logs_details ON audit_logs USING gin(details);

COMMIT;
