-- مكتبة القيّوم | فهارس مساحات المجتمع ومراجعة المنشورات والعضويات
BEGIN;
SET search_path TO qayyum, public;
CREATE INDEX IF NOT EXISTS idx_community_spaces_public ON community_spaces(space_kind, created_at DESC) WHERE status='active' AND privacy='public';
CREATE INDEX IF NOT EXISTS idx_community_spaces_owner_queue ON community_spaces(created_at) WHERE status='pending_owner_review';
CREATE INDEX IF NOT EXISTS idx_community_members_user_status ON community_members(user_id, membership_status, space_id);
CREATE INDEX IF NOT EXISTS idx_community_members_space_status ON community_members(space_id, membership_status, member_role);
CREATE INDEX IF NOT EXISTS idx_community_posts_visible_feed ON community_posts(space_id, created_at DESC) WHERE moderation_status='visible';
CREATE INDEX IF NOT EXISTS idx_community_posts_review_queue ON community_posts(space_id, created_at) WHERE moderation_status='pending';
COMMIT;
