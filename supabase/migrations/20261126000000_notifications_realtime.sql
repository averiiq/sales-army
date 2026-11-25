-- ============================================================================
-- 20261126000000_notifications_realtime.sql
--
-- Admin broadcast messages (public.notifications) were never delivered live:
-- the table was not part of the supabase_realtime publication, so the app's
-- realtime subscription received nothing. Realtime still applies the
-- notification_read RLS policy per subscriber (own agency + broadcasts only).
--
-- Additive and idempotent.
-- ============================================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
END $$;

-- Newest-first inbox loads per agency and for platform-wide broadcasts.
CREATE INDEX IF NOT EXISTS idx_notifications_tenant_created ON public.notifications (tenant_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_broadcast_created ON public.notifications (created_at DESC) WHERE is_broadcast;
