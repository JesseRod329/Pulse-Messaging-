# BeamBox V2 Stabilization + Refactor Plan (Decision-Complete)

## Summary
This plan addresses your assessment with a production-hardening sequence that fixes correctness/security first, then structural maintainability, then coverage/accessibility.

Locked decisions from this session:
- AppCoordinator strategy: **full split now** (not incremental facade).
- Token migration: **auto-migrate UserDefaults tokens to Keychain**.
- Inventory concurrency: **Postgres RPC with row-level locks and atomic transaction**.

Repo grounding notes:
- Your “God Object”, token storage, ETA math bug, stock race, no refresh, thread-safety, sign-out leakage, test gaps are all real in current code.
- One correction: `errorMessage` is currently surfaced via `.alert` in `/Users/jesse/pulse/Boppy/v2/ios/BoppyV2App/Sources/App/RootView.swift`, so errors are not silent, but they are still untyped and low-quality.

## Scope
- iOS app hardening and architecture split.
- Supabase backend atomicity/concurrency fixes.
- Test and reliability upgrades.
- Accessibility baseline (Dynamic Type + VoiceOver labels for primary controls).

## Out of Scope
- Visual redesign.
- New product features.
- Admin web parity changes (unless required for shared API behavior).

## Important Public API / Interface / Type Changes
1. iOS auth/session interfaces
- Add protocol in `/Users/jesse/pulse/Boppy/v2/ios/BoppyV2App/Sources/App/Services/SessionTokenStore.swift`:
  - `readTokens()`, `saveTokens(...)`, `clearTokens()`, `migrateFromLegacyStoreIfNeeded()`.
- Replace direct `SupabaseSessionStore` usage in `/Users/jesse/pulse/Boppy/v2/ios/BoppyV2App/Sources/App/Services/LiveSupabaseBackend.swift` with protocol-backed token store.

2. iOS error model
- Add typed app error enum in `/Users/jesse/pulse/Boppy/v2/ios/BoppyV2App/Sources/App/Models/AppError.swift` with categories:
  - auth/session-expired
  - validation
  - network-timeout
  - backend
  - unknown
- `AppCoordinator` replacement stores publish typed errors, UI maps to user-safe copy.

3. Backend transactional RPC
- Add SQL functions via new migration:
  - `public.reserve_order_inventory_atomic(p_order_id uuid, p_actor_id uuid)`
  - `public.restock_order_inventory_atomic(p_order_id uuid, p_actor_id uuid)`
  - `public.build_route_atomic(p_channel_id uuid, p_driver_id uuid, p_start_lat double precision, p_start_lng double precision, p_actor_id uuid, p_approximate boolean, p_order_ids uuid[], p_eta_minutes int[])`
- Edge functions `/Users/jesse/pulse/Boppy/v2/backend/supabase/functions/update-order-status/index.ts` and `/Users/jesse/pulse/Boppy/v2/backend/supabase/functions/build-route/index.ts` call RPCs instead of multi-call partial writes.

4. Schema/index additions
- Add indexes:
  - `order_ledger_events(actor_id, created_at desc)`
  - `inventory_stock_ledger(actor_id, created_at desc)`
  - `admin_audit_events(actor_id, created_at desc)`

## Implementation Plan

### Phase 1 — Correctness + Security Hotfixes (P0)
1. Fix ETA unit bug.
- Modify `/Users/jesse/pulse/Boppy/v2/ios/BoppyV2App/Sources/Core/Routing/DistanceRouter.swift`.
- Keep Earth radius in km and convert to miles before mph math, or switch speed to km/h consistently.
- Update `/Users/jesse/pulse/Boppy/v2/ios/BoppyV2App/Tests/CoreTests/DistanceRouterTests.swift` with numeric assertions against known coordinates.

2. Move token persistence to Keychain with migration.
- Create `/Users/jesse/pulse/Boppy/v2/ios/BoppyV2App/Sources/App/Services/KeychainSessionStore.swift`.
- Keep `/Users/jesse/pulse/Boppy/v2/ios/BoppyV2App/Sources/App/Services/SupabaseSessionStore.swift` as legacy migration source only.
- On app bootstrap, migrate once then clear legacy values.
- Add tests for migration and clear behavior.

3. Add auth refresh flow + one retry.
- Modify `/Users/jesse/pulse/Boppy/v2/ios/BoppyV2App/Sources/App/Services/SupabaseRESTClient.swift`.
- Add `refreshSession(refreshToken:)` call to Supabase auth token endpoint.
- For 401/403 on REST/edge calls: refresh once, retry once, then throw unauthorized.
- Add timeout config with custom URLSession in client init (connect/request/resource limits).

### Phase 2 — AppCoordinator Full Split (P0/P1)
1. Replace God object with domain stores.
- Create:
  - `/Users/jesse/pulse/Boppy/v2/ios/BoppyV2App/Sources/App/Stores/AuthStore.swift`
  - `/Users/jesse/pulse/Boppy/v2/ios/BoppyV2App/Sources/App/Stores/FeedStore.swift`
  - `/Users/jesse/pulse/Boppy/v2/ios/BoppyV2App/Sources/App/Stores/OrdersStore.swift`
  - `/Users/jesse/pulse/Boppy/v2/ios/BoppyV2App/Sources/App/Stores/DispatchStore.swift`
  - `/Users/jesse/pulse/Boppy/v2/ios/BoppyV2App/Sources/App/Stores/ProfileAdminStore.swift`
  - `/Users/jesse/pulse/Boppy/v2/ios/BoppyV2App/Sources/App/Stores/AppShellStore.swift`
- Remove cross-domain state coupling from `/Users/jesse/pulse/Boppy/v2/ios/BoppyV2App/Sources/App/Coordinator/AppCoordinator.swift`.
- Keep one lightweight composition root object only for dependency wiring.

2. Fix thread safety around cached session.
- Make session state actor-isolated:
  - either convert `LiveSupabaseBackend` to `actor`
  - or introduce `/Users/jesse/pulse/Boppy/v2/ios/BoppyV2App/Sources/App/Services/SessionStateActor.swift`.
- All cached session reads/writes route through actor.

3. Fix sign-out state leakage.
- Ensure sign-out clears:
  - invite token input
  - latest invite
  - active order sheet state
  - all domain caches and polling tasks.
- Validate at store level and root integration.

### Phase 3 — Backend Atomicity + Concurrency (P0)
1. Atomic inventory reserve/restock.
- Add migration `/Users/jesse/pulse/Boppy/v2/backend/supabase/migrations/20260215000006_atomic_inventory_and_route.sql`.
- In RPC: lock inventory rows in deterministic order (`FOR UPDATE`) before balance checks.
- Perform checks + updates + ledger + audit in same transaction.
- Ensure idempotency by reason key guards in-transaction.

2. Atomic route build.
- RPC does route insert + stop insert + order status updates + ledger writes in one transaction.
- `build-route` edge function computes plan, passes to RPC, returns committed payload only.
- No partial route records on failure.

3. Add missing actor_id indexes.
- Same migration adds indexes listed above.

### Phase 4 — Error Handling Quality (P1)
1. Typed error mapping.
- Map `SupabaseClientError` + HTTP status into `AppError`.
- Replace direct `error.localizedDescription` fan-out with structured mapping in stores.

2. User-facing behavior.
- Keep current global alert in `/Users/jesse/pulse/Boppy/v2/ios/BoppyV2App/Sources/App/RootView.swift`.
- Add retry actions for network-timeout and transient server categories.
- Add analytics event for error category and screen context.

### Phase 5 — Accessibility + Maintainability + Test Coverage (P1/P2)
1. Dynamic Type baseline.
- Replace hardcoded `Font.system(size:)` in core screens with text styles where feasible:
  - `/Users/jesse/pulse/Boppy/v2/ios/BoppyV2App/Sources/App/Features/Feed/*`
  - `/Users/jesse/pulse/Boppy/v2/ios/BoppyV2App/Sources/App/Features/Orders/*`
  - `/Users/jesse/pulse/Boppy/v2/ios/BoppyV2App/Sources/App/Features/Dispatch/*`
  - `/Users/jesse/pulse/Boppy/v2/ios/BoppyV2App/Sources/App/Features/Profile/*`
- Use `minimumScaleFactor` only for constrained badges.

2. VoiceOver labels/hints for primary controls.
- Add explicit labels/hints for dispatch map controls, quick order actions, filter tabs, destructive admin controls.

3. Replace placeholder smoke tests.
- Replace `/Users/jesse/pulse/Boppy/v2/ios/BoppyV2App/Tests/AppTests/SmokeTests.swift` `assertTrue(true)` tests with real integration tests:
  - sign-in bootstrap
  - state reset on sign-out
  - token migration
  - refresh retry path
  - route ETA deterministic expectations.

4. Break down large FeedView.
- Split `/Users/jesse/pulse/Boppy/v2/ios/BoppyV2App/Sources/App/Features/Feed/FeedView.swift` into smaller components/store bindings:
  - feed shell
  - owner composer
  - channel thread sheet
  - post list container.

## Commit Sequence
1. `fix(v2): correct distance ETA unit conversion and tests`
2. `feat(v2): add keychain token store with legacy migration`
3. `feat(v2): implement auth refresh and request retry`
4. `refactor(v2): split app coordinator into domain stores`
5. `fix(v2): clear invite and session artifacts on sign-out`
6. `feat(v2): add atomic inventory and route RPCs`
7. `refactor(v2): route edge functions through atomic RPCs`
8. `perf(v2): add actor_id indexes for ledger and audit queries`
9. `refactor(v2): typed app errors and retry-capable UI mapping`
10. `test(v2): replace placeholder smoke tests with functional coverage`
11. `a11y(v2): dynamic type and voiceover baseline for core screens`

## Test Cases and Scenarios

### iOS
1. Session migration
- Given tokens in UserDefaults and empty Keychain, first launch migrates to Keychain and removes UserDefaults tokens.
2. Refresh retry
- Given expired access token and valid refresh token, first request refreshes and retries successfully.
3. Unauthorized fallback
- Given expired access and invalid refresh, app transitions to signed-out state with clear error.
4. Sign-out hygiene
- Given active invite/order/session state, sign-out clears all state and no stale values render.
5. ETA correctness
- Known coordinate pair returns ETA consistent with selected speed unit logic.
6. Accessibility
- VoiceOver can identify primary actions; Dynamic Type does not clip critical controls.

### Backend
1. Concurrent reserve
- Two simultaneous reserve requests for same stock cannot oversell.
2. Restock idempotency
- Repeated cancel/retry does not double-restock.
3. Route atomicity
- If stop insert or ledger write fails, route/order state remains unchanged.
4. Index usage check
- Query plans for actor-centric audit/ledger requests use new indexes.

### End-to-End
1. Owner accepts quote with line items under concurrent load and stock integrity is preserved.
2. Owner builds route and all side effects commit together or not at all.
3. Session expiry during active use refreshes seamlessly once, then recovers or signs out cleanly.

## Verification Commands
- `cd /Users/jesse/pulse/Boppy/v2/ios/BoppyV2App && swift test`
- `xcodebuild -project /Users/jesse/pulse/Boppy/v2/ios/BoppyV2App/BoppyV2App.xcodeproj -scheme BoppyV2App -destination 'generic/platform=iOS Simulator' build`
- `cd /Users/jesse/pulse/Boppy/v2/backend/supabase/functions && deno check */index.ts`
- `supabase db push --project-ref <project-ref>`
- `supabase functions deploy update-order-status build-route`
- Run existing RLS/extended smoke scripts after deploy.

## Acceptance Criteria
1. No UserDefaults token persistence in active path.
2. Access-token expiry does not force immediate logout when refresh token is valid.
3. No inventory oversell under concurrent reserve tests.
4. No partial route artifacts on failed route builds.
5. AppCoordinator responsibilities are split into domain stores.
6. Placeholder smoke tests removed and replaced with assertions against real behavior.
7. Core screens pass basic Dynamic Type and VoiceOver checks.

## Assumptions and Defaults
1. Repo root for execution is `/Users/jesse/pulse/Boppy`.
2. Branch policy remains feature branches prefixed `codex/` and merge through PR.
3. Supabase project and secrets are already configured for migration/function deploy.
4. Current visual style remains; this plan changes architecture/reliability more than UI aesthetics.
5. Existing in-flight uncommitted UI work is preserved and not force-reverted during this plan.
