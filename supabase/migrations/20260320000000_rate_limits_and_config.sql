-- Lapse: row count limits, payload size constraints, and app config table.
-- Protects against single-user abuse of database storage and egress.

BEGIN;

-- ══════════════════════════════════════════════════════════════════════
-- ROW COUNT LIMITS (per user)
-- ══════════════════════════════════════════════════════════════════════

-- For tables with is_deleted (decks, cards) — excludes soft-deleted rows
-- so that deleting frees up a slot immediately.
CREATE OR REPLACE FUNCTION enforce_row_limit()
RETURNS trigger AS $$
DECLARE
  row_count integer;
  max_rows  integer := (TG_ARGV[0])::integer;
BEGIN
  EXECUTE format(
    'SELECT count(*) FROM %I.%I WHERE user_id = $1 AND NOT is_deleted',
    TG_TABLE_SCHEMA, TG_TABLE_NAME
  ) INTO row_count USING NEW.user_id;

  IF row_count >= max_rows THEN
    RAISE EXCEPTION 'Row limit exceeded: maximum % allowed per user', max_rows
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- For tables without is_deleted (reviews, session summaries) — counts all rows.
CREATE OR REPLACE FUNCTION enforce_row_limit_total()
RETURNS trigger AS $$
DECLARE
  row_count integer;
  max_rows  integer := (TG_ARGV[0])::integer;
BEGIN
  EXECUTE format(
    'SELECT count(*) FROM %I.%I WHERE user_id = $1',
    TG_TABLE_SCHEMA, TG_TABLE_NAME
  ) INTO row_count USING NEW.user_id;

  IF row_count >= max_rows THEN
    RAISE EXCEPTION 'Row limit exceeded: maximum % allowed per user', max_rows
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Decks: 100 per user
CREATE TRIGGER enforce_deck_limit
  BEFORE INSERT ON public.decks
  FOR EACH ROW EXECUTE FUNCTION enforce_row_limit('100');

-- Cards: 10,000 per user
CREATE TRIGGER enforce_card_limit
  BEFORE INSERT ON public.cards
  FOR EACH ROW EXECUTE FUNCTION enforce_row_limit('10000');

-- Reviews: 10,000 per user
CREATE TRIGGER enforce_review_limit
  BEFORE INSERT ON public.reviews
  FOR EACH ROW EXECUTE FUNCTION enforce_row_limit_total('10000');

-- Session summaries: 5,000 per user
CREATE TRIGGER enforce_session_summary_limit
  BEFORE INSERT ON public.review_session_summary
  FOR EACH ROW EXECUTE FUNCTION enforce_row_limit_total('5000');

-- ══════════════════════════════════════════════════════════════════════
-- PAYLOAD SIZE CONSTRAINTS
-- ══════════════════════════════════════════════════════════════════════

-- Server-side maximums — client-side limits are stricter (50 / 300 chars)
-- but these prevent API-level abuse bypassing the client.
ALTER TABLE public.decks
  ADD CONSTRAINT chk_deck_name_length CHECK (length(deck_name) <= 100);

ALTER TABLE public.cards
  ADD CONSTRAINT chk_front_length CHECK (length(front) <= 2000),
  ADD CONSTRAINT chk_back_length CHECK (length(back) <= 2000);

-- ══════════════════════════════════════════════════════════════════════
-- APP CONFIG (min version, future server-side settings)
-- ══════════════════════════════════════════════════════════════════════

CREATE TABLE public.app_config (
  key   text PRIMARY KEY,
  value text NOT NULL
);

INSERT INTO public.app_config (key, value) VALUES ('min_app_version', '0.3.0');

ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone authenticated can read config"
  ON public.app_config FOR SELECT TO authenticated
  USING (true);

-- No INSERT/UPDATE/DELETE for any role — only postgres (admin) can modify.
REVOKE ALL ON TABLE public.app_config FROM anon;
REVOKE ALL ON TABLE public.app_config FROM authenticated;
GRANT SELECT ON TABLE public.app_config TO authenticated;

COMMIT;
