-- Fix: decks RLS infinite recursion (PostgrestException 42P17).
--
-- The INSERT and UPDATE policies on decks contained a subquery
-- `SELECT 1 FROM public.decks` to verify parent_id ownership.
-- This triggers the SELECT policy on the same table, which Postgres
-- detects as infinite recursion.
--
-- Removing this check is safe because:
-- - user_id = auth.uid() already ensures rows belong to the current user
-- - The FK constraint (parent_id REFERENCES decks(deck_id)) ensures
--   referential integrity
-- - A user setting parent_id to another user's deck_id is harmless — the
--   parent would be invisible via RLS, and no data leaks
-- - The client only sets parent_id from its own deck tree

BEGIN;

DROP POLICY "Users can insert their own decks" ON public.decks;
CREATE POLICY "Users can insert their own decks"
  ON public.decks FOR INSERT TO authenticated
  WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY "Users can update their own decks" ON public.decks;
CREATE POLICY "Users can update their own decks"
  ON public.decks FOR UPDATE TO authenticated
  USING ((select auth.uid()) = user_id)
  WITH CHECK ((select auth.uid()) = user_id);

COMMIT;
