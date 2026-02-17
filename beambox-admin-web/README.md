# BeamBox Admin Web

Operator-focused admin console for BeamBox V2 edge functions.

## What this repo contains

- Typed edge client modules:
  - `src/lib/api/types.ts`
  - `src/lib/api/client.ts`
  - `src/lib/api/inventory.ts`
  - `src/lib/api/orders.ts`
  - `src/lib/api/admin.ts`
- Admin surfaces in one app shell:
  - Orders
  - Inventory
  - Dispatch
  - Channels
  - Members
  - Audit
- Error handling with request-context and explicit rate-limit guidance.

## Environment

Copy `.env.example` to `.env.local` and set values:

```bash
cp .env.example .env.local
```

Required vars:

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_FUNCTIONS_BASE_URL`
- `VITE_SUPABASE_ANON_KEY`

The app uses an owner bearer token entered in the UI for authenticated calls.

## Run

```bash
npm install
npm run dev
```

## Verification

```bash
npm run typecheck
npm test
npm run build
```

## Wave D / E integration

This repo is expected at:

- `/Users/jesse/pulse/beambox-admin-web`

BeamBox UAT runner consumes it via:

```bash
ADMIN_WEB_DIR=/Users/jesse/pulse/beambox-admin-web ./v2/scripts/run-uat-checklist.sh
```
