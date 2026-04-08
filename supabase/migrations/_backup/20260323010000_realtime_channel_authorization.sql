-- Authorize private Realtime channels for sync.
-- Users can only subscribe to their own sync channel: user:{user_id}:sync

BEGIN;

-- Enable RLS on the Realtime messages table (idempotent).
ALTER TABLE realtime.messages ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to receive broadcasts on their own sync channel.
CREATE POLICY "Users can listen to own sync channel"
ON realtime.messages
FOR SELECT
TO authenticated
USING (
  realtime.topic() = 'user:' || (select auth.uid())::text || ':sync'
);

COMMIT;
