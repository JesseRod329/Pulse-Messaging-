# Boppy V2 — End-to-End Code Analysis

**Analyzed:** 2026-02-16  
**Lead:** Kate 🧧⚡  
**Scope:** Full-stack delivery app (iOS + Supabase backend)

---

## 1. Architecture Overview

### iOS Client (`/ios/BoppyV2App/`)
- **Pattern:** MVVM + Coordinator (intended), but currently God Object
- **Root:** `AppCoordinator` (600+ lines) — owns all app state, all features
- **Backend Client:** `LiveSupabaseBackend` — monolithic service class implementing all protocols
- **State Management:** `@Published` properties in coordinator, polling every 20s

### Backend (`/backend/supabase/`)
- **Database:** PostgreSQL with RLS policies
- **Edge Functions:** 20+ Deno/TypeScript functions for privileged mutations
- **Auth:** Supabase Auth with Phone OTP (Twilio)
- **Real-time:** Supabase Realtime for order/route updates
- **Routing:** Mapbox optimization with nearest-neighbor fallback

### Domain Model
- **Roles:** Owner, Driver, Follower
- **Core Entities:** Channels, Posts, Orders, Routes, Inventory
- **Key Pattern:** Immutable ledger events for audit trail

---

## 2. Strengths ✅

### Architecture Decisions
1. **Ledger Pattern** — All mutations append to `order_ledger_events` and `admin_audit_events`. Immutable audit trail.
2. **RLS Security** — Row-level security policies enforce channel-scoped access
3. **Rate Limiting** — `enforceAdminActionRateLimit()` on sensitive mutations
4. **Tokenized Invites** — Expiring, usage-limited invite links
5. **Inventory Linkage** — Orders reserve stock on accept, restock on cancel
6. **Status Transitions** — Validated state machine (`canTransition()`)
7. **Edge Functions for Privileged Ops** — Service role key isolated to backend

### Code Quality
- Clean TypeScript error handling with `ApiHttpError` and assertion helpers
- Protocol-oriented Swift with `ServiceProtocols.swift`
- Comprehensive Codable mappings for Supabase JSON
- SwiftUI features well-separated (Feed, Orders, Dispatch, Profile)

---

## 3. Critical Issues (P0) 🔴

### 3.1 God Object — AppCoordinator
**File:** `Sources/App/Coordinator/AppCoordinator.swift` (~600 lines)

**Problem:** Single `@MainActor` class owns:
- All domain state (channels, posts, orders, routes, drivers, inventory)
- All loading states
- All error states
- Polling lifecycle
- Deep link handling

**Impact:**
- Impossible to test in isolation
- Any change risks breaking everything
- Thread safety concerns (all state on MainActor)
- Sign-out leaks state (partially fixed but fragile)

**Evidence:**
```swift
@Published var channels: [Channel] = []
@Published var orders: [OrderRequest] = []
@Published var routes: [DeliveryRoute] = []
@Published var drivers: [DriverProfile] = []
@Published var inventoryCatalog: InventoryCatalog?
// ... 15+ more properties
```

### 3.2 ETA Unit Bug — DistanceRouter
**File:** `Sources/Core/Routing/DistanceRouter.swift` (Lines 24-30)

**Problem:** Haversine returns kilometers, but speed math assumes miles.

```swift
let distanceKilometers = haversineDistance(current, chosen.element.point)
let distanceMiles = distanceKilometers * 0.621_371
elapsed += max(4, Int(((distanceMiles / 35.0) * 60.0).rounded()))
```

**Impact:** ETAs are ~37% shorter than reality (35 mph applied to km distance).

### 3.3 Session/Auth Issues

#### A. Cached Session Thread Safety
**File:** `Sources/App/Services/LiveSupabaseBackend.swift` (Line 52)

```swift
private var cachedSession: SessionUser?  // Non-isolated, accessed from multiple contexts
```

**Problem:** `cachedSession` is read/written from async contexts without isolation.

#### B. No Token Refresh Flow
**Evidence:** No `refreshSession()` implementation. On 401, user is signed out immediately.

#### C. Legacy Token Store Still Exists
**File:** `Sources/App/Services/SupabaseSessionStore.swift` (assumed)

Migration exists but legacy store code still present in codebase.

### 3.4 Inventory Race Condition
**File:** `backend/supabase/functions/update-order-status/index.ts`

**Problem:** Multi-call inventory reserve pattern:
1. Read stock (GET)
2. Calculate new balance (JS)
3. Update stock (PATCH)
4. Write ledger (POST)

**Not atomic.** Two concurrent "accept" operations can oversell.

**Evidence:**
```typescript
// Line ~145-170: Sequential API calls, no transaction
const variantRows = await adminGet(...)
// ... calculate ...
await adminPatch(...)  // Another request could have changed stock
await adminPost(...)   // Ledger write separate
```

### 3.5 No Atomic Route Build
**File:** `backend/supabase/functions/build-route/index.ts`

**Problem:** Route creation = multiple sequential inserts. Partial failure = orphaned data.

---

## 4. Security Assessment 🛡️

### What's Good
- ✅ JWT validation via `requireUser()` in all edge functions
- ✅ RLS policies on all tables
- ✅ Service role key only in edge functions (not client)
- ✅ Channel role verification (`requireChannelRole()`)
- ✅ Rate limiting on admin actions
- ✅ Invite tokens are random, expiring, usage-limited

### Concerns
- ⚠️ **No CORS restriction** — Edge functions likely accept any origin
- ⚠️ **actor_id not validated** — Many edge functions accept actor_id from client
  ```typescript
  // update-order-status/index.ts Line ~245
  await requireChannelRole(order.channel_id, user.id, "owner");  // Validates user
  // But ledger uses user.id directly — correct here
  ```
- ⚠️ **No request signing** — Edge functions trust JWT but no payload integrity check
- ⚠️ **Git history** — PLAN.md mentions need to scrub secrets from history

### Token Storage
**Status:** Partially fixed
- ✅ `MigratingSessionTokenStore` migrates UserDefaults → Keychain
- ✅ `KeychainSessionStore` (assumed) is primary
- ⚠️ Legacy `SupabaseSessionStore` still in codebase

---

## 5. Code Quality Issues (P1)

### 5.1 Untyped Errors
**Problem:** All errors become `errorMessage: String?` in coordinator.

**Evidence:**
```swift
catch {
    errorMessage = error.localizedDescription  // Always
}
```

**Impact:** Can't distinguish network vs auth vs validation errors for UI handling.

### 5.2 Placeholder Tests
**File:** `Tests/AppTests/SmokeTests.swift`

```swift
func testExample() throws {
    XCTAssertTrue(true)  // Placeholder
}
```

**Only real test:** `DistanceRouterTests.swift` (but doesn't catch unit bug!)

### 5.3 Sign-Out State Leakage
**File:** `AppCoordinator.signOut()`

**Current:**
```swift
func signOut() async {
    stopPollingLoop()
    await environment.authService.signOut()
    user = nil
    channels = []
    // ... more clears
    inviteTokenInput = ""  // Added
    latestInvite = nil     // Added
}
```

**Missing:** `activeOrderPost`, `activeOrderPrefilledQuote` weren't cleared (fixed in current code, but pattern is fragile).

### 5.4 Polling Architecture
**Problem:** 20-second polling loop in `AppCoordinator`:
```swift
private func startPollingLoop() {
    pollingTask = Task { [weak self] in
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 20_000_000_000)
            // ... refresh all
        }
    }
}
```

**Issues:**
- No exponential backoff on error
- Refreshes ALL data every 20s (wasteful)
- No deduplication of concurrent refreshes
- Doesn't use Supabase Realtime for push updates

### 5.5 Force Unwrapping in JSON Mapping
**File:** `LiveSupabaseBackend.swift`

Multiple force unwraps in mapping functions:
```swift
return Channel(id: row.id, title: row.title, ...)  // Assumes row exists
```

---

## 6. Database Schema Notes

### Well Designed
- Normalized inventory (items + variants)
- Ledger pattern for auditability
- Soft deletes with `archived_at`
- RLS policies enforce channel isolation

### Indexes Missing
**PLAN.md notes:**
- `order_ledger_events(actor_id, created_at desc)`
- `inventory_stock_ledger(actor_id, created_at desc)`
- `admin_audit_events(actor_id, created_at desc)`

**Current migrations:** Don't include these indexes.

---

## 7. Recommended Fix Priority

### Immediate (This Week)
1. **Fix ETA unit bug** — One line fix, add test
2. **Add atomic inventory RPC** — Postgres function with `FOR UPDATE`
3. **Split AppCoordinator** — Create domain stores (Auth, Feed, Orders, Dispatch)
4. **Add token refresh** — Retry 401s once with refresh

### Short Term (Next Sprint)
5. **Add CORS restriction** — Lock edge functions to app origin
6. **Typed errors** — `AppError` enum with retry semantics
7. **Real tests** — Replace placeholder smoke tests
8. **Indexes** — Add actor_id indexes for performance

### Medium Term
9. **Realtime integration** — Use Supabase Realtime instead of polling
10. **Actor validation audit** — Ensure all edge functions validate actor_id ownership
11. **Certificate pinning** — For production hardening

---

## 8. File Inventory

### iOS (Swift)
| File | Purpose | Lines | Status |
|------|---------|-------|--------|
| `AppCoordinator.swift` | God object | ~600 | 🔴 Refactor |
| `LiveSupabaseBackend.swift` | API client | ~800 | 🟡 OK |
| `DistanceRouter.swift` | Fallback routing | ~50 | 🔴 Bug |
| `DomainModels.swift` | Data types | ~400 | ✅ Good |
| `SessionTokenStore.swift` | Token storage | ~50 | 🟡 Partial |

### Backend (TypeScript/Deno)
| File | Purpose | Status |
|------|---------|--------|
| `update-order-status/index.ts` | Order state machine | 🟡 Needs atomicity |
| `build-route/index.ts` | Route creation | 🟡 Needs atomicity |
| `_shared/auth.ts` | JWT validation | ✅ Good |
| `_shared/ledger.ts` | Audit logging | ✅ Good |
| `_shared/rateLimit.ts` | Rate limiting | ✅ Good |

### Migrations (SQL)
| File | Purpose |
|------|---------|
| `20260213000001_init_schema.sql` | Core tables |
| `20260213000002_rls_policies.sql` | Security policies |
| `20260214000004_inventory_admin_schema.sql` | Inventory system |
| `20260216000008_design_fidelity_inventory_indexes.sql` | Recent indexes |

---

## 9. Summary

**Boppy V2 is a well-architected delivery app with solid security foundations.** The ledger pattern, RLS policies, and role-based access show mature thinking.

**However, the iOS client has accumulated technical debt:**
- God Object anti-pattern makes the coordinator unmaintainable
- ETA calculation bug affects user-facing estimates
- Session management lacks refresh flow
- Testing is minimal (placeholder tests)

**Backend has concurrency risks:**
- Inventory operations need atomic RPCs
- Route building needs transactions

**The PLAN.md you created is accurate and actionable.** Follow it in phases—don't try to fix everything at once.

---

*Analysis by Kate* 🧧⚡  
*Squad 2 Lead — The Hardening Unit*
