-- Lapse: initial schema — tables, indexes, triggers, RLS, privileges
-- All four tables in one atomic transaction.

BEGIN;

-- ══════════════════════════════════════════════════════════════════════
-- TABLES
-- ══════════════════════════════════════════════════════════════════════

CREATE TABLE public.decks (
  deck_id     uuid PRIMARY KEY,
  parent_id   uuid REFERENCES public.decks(deck_id) ON DELETE CASCADE,
  deck_name   text NOT NULL,
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  is_deleted  boolean NOT NULL DEFAULT false,
  CONSTRAINT chk_deck_name_not_empty CHECK (deck_name != '')
);

CREATE TABLE public.cards (
  card_id         uuid PRIMARY KEY,
  deck_id         uuid NOT NULL REFERENCES public.decks(deck_id) ON DELETE CASCADE,
  front           text NOT NULL,
  back            text NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  is_deleted      boolean NOT NULL DEFAULT false,
  due_date        timestamptz NOT NULL,
  stability       double precision NOT NULL DEFAULT 0.0,
  difficulty      double precision NOT NULL DEFAULT 0.0,
  elapsed_days    integer NOT NULL DEFAULT 0,
  scheduled_days  integer NOT NULL DEFAULT 0,
  reps            integer NOT NULL DEFAULT 0,
  lapses          integer NOT NULL DEFAULT 0,
  last_review     timestamptz,
  card_state      integer NOT NULL DEFAULT 0,
  step            integer,
  user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT chk_card_state CHECK (card_state BETWEEN 0 AND 3),
  CONSTRAINT chk_front_not_empty CHECK (front != ''),
  CONSTRAINT chk_back_not_empty CHECK (back != '')
);

CREATE TABLE public.reviews (
  review_id       uuid PRIMARY KEY,
  card_id         uuid NOT NULL REFERENCES public.cards(card_id) ON DELETE CASCADE,
  reviewed_at     timestamptz NOT NULL,
  rating          integer NOT NULL,
  scheduled_days  integer NOT NULL,
  elapsed_days    integer NOT NULL,
  state           integer NOT NULL,
  user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT chk_rating CHECK (rating BETWEEN 1 AND 4),
  CONSTRAINT chk_review_state CHECK (state BETWEEN 0 AND 3)
);

CREATE TABLE public.review_session_summary (
  id              uuid PRIMARY KEY,
  user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date            date NOT NULL,
  started_at      timestamptz NOT NULL,
  ended_at        timestamptz NOT NULL,
  total_reviews   integer NOT NULL DEFAULT 0,
  again_count     integer NOT NULL DEFAULT 0,
  hard_count      integer NOT NULL DEFAULT 0,
  good_count      integer NOT NULL DEFAULT 0,
  easy_count      integer NOT NULL DEFAULT 0,
  new_count       integer NOT NULL DEFAULT 0,
  learning_count  integer NOT NULL DEFAULT 0,
  review_count    integer NOT NULL DEFAULT 0,
  duration_ms     integer NOT NULL DEFAULT 0,
  updated_at      timestamptz NOT NULL DEFAULT now()
);

-- ══════════════════════════════════════════════════════════════════════
-- INDEXES
-- ══════════════════════════════════════════════════════════════════════

-- Deck lookups
CREATE INDEX idx_decks_parent_id ON public.decks(parent_id)
  WHERE NOT is_deleted AND parent_id IS NOT NULL;
CREATE INDEX idx_decks_user_id ON public.decks(user_id)
  WHERE NOT is_deleted;

-- Card lookups
CREATE INDEX idx_cards_due_date ON public.cards(due_date)
  WHERE NOT is_deleted;
CREATE INDEX idx_cards_deck_due ON public.cards(deck_id, due_date)
  WHERE NOT is_deleted;
CREATE INDEX idx_cards_user_id ON public.cards(user_id)
  WHERE NOT is_deleted;

-- Review lookups
CREATE INDEX idx_reviews_card_id ON public.reviews(card_id);
CREATE INDEX idx_reviews_reviewed_at ON public.reviews(reviewed_at);
CREATE INDEX idx_reviews_user_id ON public.reviews(user_id);

-- Session summary lookups
CREATE INDEX idx_session_summary_user_id ON public.review_session_summary(user_id);
CREATE INDEX idx_session_summary_user_date ON public.review_session_summary(user_id, date);

-- Sync pull indexes (fetch changes since last sync)
CREATE INDEX idx_decks_user_updated ON public.decks(user_id, updated_at);
CREATE INDEX idx_cards_user_updated ON public.cards(user_id, updated_at);
CREATE INDEX idx_reviews_user_reviewed ON public.reviews(user_id, reviewed_at);
CREATE INDEX idx_session_summary_user_updated ON public.review_session_summary(user_id, updated_at);

-- ══════════════════════════════════════════════════════════════════════
-- UPDATED_AT TRIGGER (custom function, no extension dependency)
-- ══════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger AS $$
BEGIN
  new.updated_at = now();
  RETURN new;
END;
$$ LANGUAGE plpgsql;

-- Reviews are immutable — no trigger needed
CREATE TRIGGER handle_updated_at BEFORE UPDATE ON public.decks
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER handle_updated_at BEFORE UPDATE ON public.cards
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER handle_updated_at BEFORE UPDATE ON public.review_session_summary
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ══════════════════════════════════════════════════════════════════════
-- ROW LEVEL SECURITY
-- ══════════════════════════════════════════════════════════════════════

ALTER TABLE public.decks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.review_session_summary ENABLE ROW LEVEL SECURITY;

-- Decks: SELECT + INSERT + UPDATE (no client-side hard-delete)
CREATE POLICY "Users can view their own decks"
  ON public.decks FOR SELECT TO authenticated
  USING ((select auth.uid()) = user_id);

CREATE POLICY "Users can insert their own decks"
  ON public.decks FOR INSERT TO authenticated
  WITH CHECK (
    (select auth.uid()) = user_id
    AND (
      parent_id IS NULL
      OR EXISTS (
        SELECT 1 FROM public.decks d
        WHERE d.deck_id = parent_id
          AND d.user_id = (select auth.uid())
      )
    )
  );

CREATE POLICY "Users can update their own decks"
  ON public.decks FOR UPDATE TO authenticated
  USING ((select auth.uid()) = user_id)
  WITH CHECK (
    (select auth.uid()) = user_id
    AND (
      parent_id IS NULL
      OR EXISTS (
        SELECT 1 FROM public.decks d
        WHERE d.deck_id = parent_id
          AND d.user_id = (select auth.uid())
      )
    )
  );

-- Cards: SELECT + INSERT + UPDATE (no client-side hard-delete)
CREATE POLICY "Users can view their own cards"
  ON public.cards FOR SELECT TO authenticated
  USING ((select auth.uid()) = user_id);

CREATE POLICY "Users can insert their own cards"
  ON public.cards FOR INSERT TO authenticated
  WITH CHECK (
    (select auth.uid()) = user_id
    AND EXISTS (
      SELECT 1 FROM public.decks d
      WHERE d.deck_id = cards.deck_id
        AND d.user_id = (select auth.uid())
    )
  );

CREATE POLICY "Users can update their own cards"
  ON public.cards FOR UPDATE TO authenticated
  USING ((select auth.uid()) = user_id)
  WITH CHECK (
    (select auth.uid()) = user_id
    AND EXISTS (
      SELECT 1 FROM public.decks d
      WHERE d.deck_id = cards.deck_id
        AND d.user_id = (select auth.uid())
    )
  );

-- Reviews: SELECT + INSERT only (immutable — no UPDATE or DELETE)
CREATE POLICY "Users can view their own reviews"
  ON public.reviews FOR SELECT TO authenticated
  USING ((select auth.uid()) = user_id);

CREATE POLICY "Users can insert their own reviews"
  ON public.reviews FOR INSERT TO authenticated
  WITH CHECK (
    (select auth.uid()) = user_id
    AND EXISTS (
      SELECT 1 FROM public.cards c
      WHERE c.card_id = reviews.card_id
        AND c.user_id = (select auth.uid())
    )
  );

-- Session summaries: SELECT + INSERT + UPDATE (never deleted)
CREATE POLICY "Users can view their own session summaries"
  ON public.review_session_summary FOR SELECT TO authenticated
  USING ((select auth.uid()) = user_id);

CREATE POLICY "Users can insert their own session summaries"
  ON public.review_session_summary FOR INSERT TO authenticated
  WITH CHECK ((select auth.uid()) = user_id);

CREATE POLICY "Users can update their own session summaries"
  ON public.review_session_summary FOR UPDATE TO authenticated
  USING ((select auth.uid()) = user_id)
  WITH CHECK ((select auth.uid()) = user_id);

-- ══════════════════════════════════════════════════════════════════════
-- PRIVILEGE MANAGEMENT (REVOKE ALL → explicit GRANT)
-- ══════════════════════════════════════════════════════════════════════

-- Block anon role entirely — app requires authentication
REVOKE ALL ON TABLE public.decks FROM anon;
REVOKE ALL ON TABLE public.cards FROM anon;
REVOKE ALL ON TABLE public.reviews FROM anon;
REVOKE ALL ON TABLE public.review_session_summary FROM anon;

-- Revoke all defaults from authenticated, then grant back only what's needed
REVOKE ALL ON TABLE public.decks FROM authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.decks TO authenticated;

REVOKE ALL ON TABLE public.cards FROM authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.cards TO authenticated;

REVOKE ALL ON TABLE public.reviews FROM authenticated;
GRANT SELECT, INSERT ON TABLE public.reviews TO authenticated;

REVOKE ALL ON TABLE public.review_session_summary FROM authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.review_session_summary TO authenticated;

COMMIT;
