CREATE TABLE IF NOT EXISTS qayyum.site_identity (
  id SMALLINT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  site_name VARCHAR(160) NOT NULL DEFAULT 'مكتبة القيّوم',
  site_subtitle VARCHAR(300) NOT NULL DEFAULT 'موسوعة ومكتبة علمية إسلامية عالمية',
  site_slogan VARCHAR(300) NOT NULL DEFAULT 'العلم نور .. والبحث عبادة',
  footer_note VARCHAR(300) NOT NULL DEFAULT 'معرفة · إيمان · حضارة',
  logo_object_key TEXT,
  logo_mime_type VARCHAR(80),
  emblem_object_key TEXT,
  emblem_mime_type VARCHAR(80),
  favicon_object_key TEXT,
  favicon_mime_type VARCHAR(80),
  updated_by UUID REFERENCES qayyum.users(id) ON DELETE SET NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
INSERT INTO qayyum.site_identity(id) VALUES(1) ON CONFLICT(id) DO NOTHING;
