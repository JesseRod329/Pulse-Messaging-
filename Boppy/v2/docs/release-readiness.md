# Release Readiness

This document tracks final production readiness for BeamBox V2.

## Required Inputs

- Supabase production project configured with latest migrations.
- Twilio production sender + verified OTP flow.
- Mapbox token configured for route optimization.
- iOS signing profiles and TestFlight distribution configured.
- Admin web environment variables set for production edge base URL.

## Readiness Gates

## 1) Backend

- [ ] Latest migrations applied:
  - `20260213000001_init_schema.sql`
  - `20260213000002_rls_policies.sql`
  - `20260213000003_retention_job.sql`
  - `20260214000004_inventory_admin_schema.sql`
  - `20260214000005_inventory_admin_rls.sql`
- [ ] Edge functions deployed and healthy.
- [ ] RLS matrix script passes for owner/driver/follower/anon role expectations.
- [ ] Rate limits on sensitive admin mutations validated.

## 2) iOS App

- [ ] `swift build` and `swift test` pass in CI and local.
- [ ] Role-specific tabs/actions behave correctly.
- [ ] Dispatch and Profile match approved layout density.
- [ ] OTP demo and live modes validated.
- [ ] Crash-free behavior acceptable in staging/TestFlight.

## 3) Admin Web

- [ ] `npm run typecheck` and `npm test` pass.
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
