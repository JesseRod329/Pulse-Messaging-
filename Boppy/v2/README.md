# Boppy V2

Ground-up rebuild for one-way invite channels and quote-based delivery orders.

## Layout

- `ios/BoppyV2App` SwiftUI app target (MVVM + Coordinator)
- `backend/supabase` Postgres schema, RLS, and edge functions
- `docs` architecture, API contracts, and operations runbook

## Product Scope (V1)

- Owner/driver/follower roles
- Owner-only posting (image/video/text)
- Invite-link channel join after phone OTP
- Long-press post to create custom quote request
- Owner order inbox with status/driver assignment
- Distance-based route build with Mapbox-first and deterministic fallback
- Immutable order ledger events

## Out of Scope (V1)

- Peer-to-peer chat
- User-created groups
- In-app payments/wallet/payouts
- Mesh/Nostr transport

## Stitch Design Promotion Workflow

- Raw Stitch exports stay in `v2/design/stitch/...`.
- Only cleaned assets/components are promoted into app code:
  - `v2/ios/BoppyV2App/Sources/App/Features/...`
  - `v2/ios/BoppyV2App/Sources/App/Components/...`
  - `v2/ios/BoppyV2App/Resources/...` (if added later)
- Do not import directly from raw design export paths in production Swift code.

### Naming Convention

- Use kebab-case for design export folders, for example:
  - `owner-feed-posting`
  - `order-request-sheet`
- Use feature-local Swift files for converted UI, for example:
  - `FeedOwnerComposerView.swift`
  - `FeedPostCardView.swift`

## Quick Start

### Backend

1. Create a Supabase project.
2. Apply SQL migrations under `backend/supabase/migrations`.
3. Set edge function secrets:
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `MAPBOX_ACCESS_TOKEN`
4. Deploy edge functions from `backend/supabase/functions`.

### iOS

1. Open `ios/BoppyV2App/BoppyV2App.xcodeproj`.
2. Set build settings from `ios/BoppyV2App/Config/xcconfig.template`.
3. Run on device for SMS OTP testing.

## Verification Commands

- `cd v2/ios/BoppyV2App && xcodegen generate`
- `cd v2/ios/BoppyV2App && swift test`
- `cd v2/backend/supabase/functions && deno check */index.ts`
