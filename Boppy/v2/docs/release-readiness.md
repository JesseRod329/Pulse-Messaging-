# Release Readiness

This document tracks final production readiness for BeamBox V2.

## Required Inputs

- Supabase production project configured with latest migrations.
- Twilio production sender + verified OTP flow.
- Mapbox token configured for route optimization.
- iOS signing profiles and TestFlight distribution configured.
- Admin web environment variables set for production edge base URL.

## Readiness Gates

## Current Snapshot (2026-02-17)

- Local iOS gate commands are passing:
  - `xcodebuild ... build` succeeded.
  - `swift test` succeeded.
  - `xcodebuild ... test` succeeded on `iPhone 16 (iOS 18.6)` with:
    - `15` app tests passed.
    - `5` UI tests passed.
- Local backend gate commands are passing:
  - `deno check */index.ts` succeeded.
  - `deno test **/*test.ts` succeeded (`17 passed`).
- Full UAT checklist now passes end-to-end in this environment:
  - `ADMIN_WEB_DIR=/Users/jesse/pulse/beambox-admin-web ./v2/scripts/run-uat-checklist.sh`
  - Summary: `Passed 7, Failed 0, Skipped 0`
- Live RLS matrix now passes using generated owner/driver/follower credentials:
  - `deno run --allow-env --allow-net v2/backend/supabase/scripts/rls-matrix-check.ts`
  - Summary: `11 passed, 0 failed`
- Admin web repo now exists at:
  - `/Users/jesse/pulse/beambox-admin-web`
  - `npm run typecheck` + `npm test` passing
- Final screenshot pack prepared at:
  - `/Users/jesse/pulse/Boppy/v2/docs/reports/screens/final-pack-2026-02-16/`
- Full evidence log:
  - `/Users/jesse/pulse/Boppy/v2/docs/reports/wave-e-closeout-2026-02-16.md`

## 1) Backend

- [ ] Latest migrations applied:
  - `20260213000001_init_schema.sql`
  - `20260213000002_rls_policies.sql`
  - `20260213000003_retention_job.sql`
  - `20260214000004_inventory_admin_schema.sql`
  - `20260214000005_inventory_admin_rls.sql`
- [ ] Edge functions deployed and healthy.
- [x] RLS matrix script passes for owner/driver/follower/anon role expectations.
- [ ] Rate limits on sensitive admin mutations validated.

## 2) iOS App

- [ ] `swift build` and `swift test` pass in CI and local.
- [x] Role-specific tabs/actions behave correctly.
- [x] Dispatch and Profile match approved layout density.
- [ ] OTP demo and live modes validated.
- [ ] Crash-free behavior acceptable in staging/TestFlight.

## 3) Admin Web

- [x] `npm run typecheck` and `npm test` pass.
- [ ] Orders/Inventory/Dispatch/Channels/Members/Audit load and mutate successfully.
- [ ] Error banners show request-context and explicit rate-limit cooldown guidance.
- [ ] Owner-only controls blocked for non-owner roles.

## 4) Observability + Operations

- [ ] Runbook up to date with latest commands and incident defaults.
- [ ] Request IDs visible in edge errors for support diagnostics.
- [ ] Data retention job schedule verified.
- [ ] Rollback playbook documented and tested in staging.

## Release Procedure

1. Run `./v2/scripts/run-uat-checklist.sh`.
2. Execute live RLS matrix with real role tokens.
3. Complete manual core journey walkthrough (owner -> follower -> owner -> driver).
4. Tag release candidate and publish TestFlight/internal admin-web deploy.
5. Monitor first 24h for OTP failures, route failures, and admin 429 spikes.

## Rollback Criteria

- Role-boundary leak.
- Order transition integrity failure.
- Dispatch stop completion corruption.
- Audit trail write failures.

If any trigger occurs, disable new rollout, revert to previous stable deployment, and run incident checklist from runbook.
