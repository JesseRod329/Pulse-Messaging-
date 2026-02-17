# Architecture

## Client

- Pattern: MVVM + Coordinator + domain stores
- Root: `AppCoordinator` is orchestration-only (routing, refresh cadence, cross-feature actions).
- Domain stores (injected via `@EnvironmentObject`):
  - `AuthStore` (session, invite state, offline and error state)
  - `FeedStore` (channels, selected channel, posts, drivers)
  - `OrderStore` (orders, ledger cache, active order sheet state)
  - `DispatchStore` (routes and stop operations)
  - `InventoryStore` (catalog and stock operations)
  - `AdminStore` (audit events and admin mutations)
- Rule: views read/write domain state through stores; coordinator handles intent orchestration.
- Runtime resilience:
  - `NetworkMonitor` updates coordinator online/offline state and surfaces a root offline banner.
  - `scenePhase` foreground activation triggers throttled refresh (`>= 30s`).

## Backend

- Supabase Postgres + RLS
- Supabase Storage for media
- Supabase Edge Functions for privileged mutations
- Postgres transactional RPCs for critical multi-step mutations:
  - `reserve_order_inventory_atomic`
  - `restock_order_inventory_atomic`
  - `build_delivery_route`
- `inventory-list` edge function enriches inventory rows with active-order counts for owner UI badges while preserving additive contracts.
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
