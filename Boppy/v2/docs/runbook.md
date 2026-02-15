# Operations Runbook

## Budget Guardrails

- Keep Supabase on Pro base tier.
- Keep single Twilio long-code number.
- Start Mapbox usage within free tier where possible.
- Enable spend and anomaly alerts in Supabase/Twilio/Mapbox dashboards.

## Incident Defaults

- OTP deliverability degraded:
  - confirm Twilio sender health
  - verify OTP retry cooldown enforcement
- Mapbox unavailable:
  - fallback route mode auto-enabled
  - banner: `approximate route ordering`
- Realtime degraded:
  - app polls orders/routes every 20 seconds

## Data Retention

- Retain order/contact data for 12 months.
- Run scheduled purge via SQL function + cron.

## Release Checklist

- RLS tests pass for role boundaries
- OTP tested on physical iPhone
- Invite expiry and usage limits tested
- Route fallback path tested by forced Mapbox error
- Crash-free rate acceptable in TestFlight pilot

## Scenario Coverage Matrix

### Admin + Inventory

- `admin-driver-memberships-upsert`
  - `add` on follower member promotes `follower -> driver`.
  - `remove` on active driver with assigned active orders returns `409 driver_has_active_orders`.
  - `remove` on driver without active assignments demotes `driver -> follower`.
- `admin-delete-order`
  - soft delete always requires non-empty reason.
  - hard delete requires `ALLOW_HARD_DELETE=true`.
  - hard delete with non-terminal status returns `409 hard_delete_not_allowed_for_status`.
- `inventory-adjust-stock`
  - decrement below zero returns `409 insufficient_stock`.
  - increment/decrement writes `inventory_stock_ledger` and `admin_audit_events`.
  - burst mutation calls over policy window return `429 rate_limited`.
- `inventory-list`
  - owner read succeeds.
  - driver read succeeds.
  - follower read is forbidden.
- `update-order-status`
  - legal transitions accepted per workflow matrix.
  - illegal jumps return `409 invalid_status_transition`.
  - burst status churn over policy window returns `429 rate_limited`.

### Dispatch + Routing

- `reorder-route-stops`
  - duplicate stop IDs rejected.
  - missing stop IDs rejected.
  - caller must be owner of channel.
- `complete-stop`
  - stop completion increments route progress.
  - duplicate completion attempts remain idempotent/no-op behavior.

### Operational Verification Commands

- Admin web:
  - `npm run typecheck`
  - `npm test`
- iOS:
  - `swift build`
  - `swift test`
- Supabase edge functions:
  - `deno check --config v2/backend/supabase/functions/deno.json <function-path>`
  - `deno test --config v2/backend/supabase/functions/deno.json v2/backend/supabase/functions/update-order-status/transitions_test.ts`
  - `deno test --config v2/backend/supabase/functions/deno.json v2/backend/supabase/functions/_shared/rateLimit_test.ts`
  - `SUPABASE_URL=... RLS_CHANNEL_ID=... RLS_OWNER_TOKEN=... RLS_DRIVER_TOKEN=... RLS_FOLLOWER_TOKEN=... deno run --allow-env --allow-net v2/backend/supabase/scripts/rls-matrix-check.ts`

### RLS Matrix Script Inputs

- `SUPABASE_URL`
  - Base project URL (used to derive `<url>/functions/v1` unless `SUPABASE_FUNCTIONS_BASE_URL` is provided).
- `SUPABASE_FUNCTIONS_BASE_URL` (optional)
  - Direct override for edge functions base URL.
- `SUPABASE_ANON_KEY` (optional, recommended)
  - Included as `apikey` header by the matrix script when present; useful in environments that require API key header alongside bearer auth.
- `RLS_CHANNEL_ID`
  - Channel used for role-matrix checks.
- `RLS_OWNER_TOKEN`
  - Valid owner bearer token for the channel.
- `RLS_DRIVER_TOKEN`
  - Valid driver bearer token for the channel.
- `RLS_FOLLOWER_TOKEN`
  - Valid follower bearer token for the channel.
