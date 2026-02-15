# Architecture

## Client

- Pattern: MVVM + Coordinator
- Root: `AppCoordinator` owns app-level route state.
- Feature modules:
  - Auth
  - Channels
  - Orders
  - Dispatch
- Rule: features emit intents, coordinator performs navigation.

## Backend

- Supabase Postgres + RLS
- Supabase Storage for media
- Supabase Edge Functions for privileged mutations
- Supabase Realtime channels for order/route updates
- Twilio-backed Supabase Phone OTP
- Mapbox optimization/directions for route generation

## Security

- JWT-backed RLS checks for all data reads/writes.
- Service role key used only in edge functions.
- Invite links are tokenized with expiry and usage limits.
- Ledger events are append-only.

## Routing Strategy

1. Geocode address during order creation.
2. If geocode fails, set status `address_review`.
3. On route build, request Mapbox optimization.
4. If Mapbox fails/timeouts, fallback to nearest-neighbor.
5. Persist route and stops transactionally.

