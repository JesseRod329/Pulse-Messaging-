# UAT Checklist

This checklist is the release gate for BeamBox V2 staging and pre-production validation.

## Automation Command

Run from repo root:

```bash
./v2/scripts/run-uat-checklist.sh
```

## Core Journey Validation

- [ ] Owner signs in and sees Feed/Orders/Dispatch/Profile with no layout overlaps.
- [ ] Owner publishes a post and it appears for follower role.
- [ ] Follower requests quote from post and order appears in owner inbox.
- [ ] Owner updates order status through legal transitions only.
- [ ] Owner assigns driver and dispatch route is buildable.
- [ ] Driver completes stops and route/order state updates correctly.
- [ ] Ledger timeline reflects key actions in chronological order.

## Inventory + Admin Validation

- [ ] Owner can create inventory item/variant and adjust stock.
- [ ] Driver can read inventory list but cannot mutate inventory.
- [ ] Follower cannot read or mutate protected admin/inventory surfaces.
- [ ] Admin destructive actions require reason and are audited.
- [ ] Rate-limited endpoints return clear 429 banner guidance in admin web.

## Security + Boundary Validation

- [ ] `deno run --allow-env --allow-net v2/backend/supabase/scripts/rls-matrix-check.ts` passes with live tokens.
- [ ] No client flow depends on service-role credentials.
- [ ] All edge responses include envelope + request ID for diagnostics.

## Visual/UX Validation

- [ ] iOS Dispatch spacing matches approved reference (map header, stop cards, bottom action stack).
- [ ] iOS Profile admin controls remain dense/readable on iPhone 17 Pro simulator.
- [ ] No bottom deadspace, white overlaps, or clipping in tab surfaces.

## Go / No-Go

- Go if all checks above pass with no high-severity defects.
- No-Go if role boundaries, order transitions, dispatch completion, or audit integrity fail.
- Save execution artifacts in `v2/docs/reports/` (RLS output, live smoke report, and simulator screenshots).
