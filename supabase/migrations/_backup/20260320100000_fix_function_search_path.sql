-- Fix mutable search_path on PL/pgSQL functions.
--
-- Supabase security advisor flags functions without an explicit search_path
-- because a malicious actor with sufficient privileges could manipulate the
-- search_path to resolve names to unexpected schemas. Setting search_path = ''
-- forces all references to be schema-qualified, preventing this vector.
--
-- All three functions already use fully-qualified references (TG_TABLE_SCHEMA
-- via format(), or only touch NEW row fields), so this is safe.

BEGIN;

ALTER FUNCTION public.set_updated_at() SET search_path = '';
ALTER FUNCTION public.enforce_row_limit() SET search_path = '';
ALTER FUNCTION public.enforce_row_limit_total() SET search_path = '';

COMMIT;
