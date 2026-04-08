-- Realtime sync broadcast triggers
-- Sends a lightweight notification via Broadcast when any synced table changes,
-- so other devices can trigger a pull immediately.

BEGIN;

-- Single trigger function shared by all synced tables.
-- Broadcasts to a private, user-scoped channel: user:{user_id}:sync
CREATE OR REPLACE FUNCTION public.broadcast_sync_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  _user_id uuid;
BEGIN
  _user_id := COALESCE(NEW.user_id, OLD.user_id);

  PERFORM realtime.send(
    jsonb_build_object('table', TG_TABLE_NAME, 'op', TG_OP),
    'sync_change',
    'user:' || _user_id::text || ':sync',
    true  -- private channel
  );

  RETURN NULL;
END;
$$;

-- Decks
CREATE TRIGGER trg_decks_sync_broadcast
  AFTER INSERT OR UPDATE OR DELETE ON public.decks
  FOR EACH ROW EXECUTE FUNCTION public.broadcast_sync_change();

-- Cards
CREATE TRIGGER trg_cards_sync_broadcast
  AFTER INSERT OR UPDATE OR DELETE ON public.cards
  FOR EACH ROW EXECUTE FUNCTION public.broadcast_sync_change();

-- Reviews (insert-only, immutable)
CREATE TRIGGER trg_reviews_sync_broadcast
  AFTER INSERT ON public.reviews
  FOR EACH ROW EXECUTE FUNCTION public.broadcast_sync_change();

-- Review session summaries
CREATE TRIGGER trg_summaries_sync_broadcast
  AFTER INSERT OR UPDATE OR DELETE ON public.review_session_summary
  FOR EACH ROW EXECUTE FUNCTION public.broadcast_sync_change();

COMMIT;
