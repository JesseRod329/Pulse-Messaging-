# Live Smoke Report

- Date: 2026-02-15 06:30:41 UTC
- Project: wgdzwtrzgmhzhyjyxdaf
- Channel: 5300f0ec-a1dd-4f99-8f7d-2883f44a31d9
- Order: baa40e38-17b4-45a2-a298-c02d9aa4dfe4

## RLS Matrix

```

RLS matrix results
==================
[PASS] owner    expected 200 got 200 - inventory-list owner read
[PASS] driver   expected 200 got 200 - inventory-list driver read
[PASS] follower expected 403 got 403 - inventory-list follower forbidden (forbidden)
[PASS] anon     expected 401 got 401 - inventory-list anon unauthorized (missing_auth)
[PASS] owner    expected 200 got 200 - admin-orders-list owner read
[PASS] driver   expected 403 got 403 - admin-orders-list driver forbidden (forbidden)
[PASS] follower expected 403 got 403 - admin-orders-list follower forbidden (forbidden)
[PASS] owner    expected 200 got 200 - admin-channel-members-list owner read
[PASS] driver   expected 403 got 403 - admin-channel-members-list driver forbidden (forbidden)
[PASS] owner    expected 200 got 200 - admin-audit-events-list owner read
[PASS] follower expected 403 got 403 - admin-audit-events-list follower forbidden (forbidden)

Total: 11  Passed: 11  Failed: 0
```

## Extended Checks

| Check | Expected | Actual | Status |
|---|---|---|---|
| Driver inventory upsert denied | forbidden | forbidden | PASS |
| Owner hard-delete policy gate | hard_delete_disabled | hard_delete_disabled | PASS |
| Reserve ledger event exists | >=1 | 1 | PASS |
| Restock ledger event exists | >=1 | 1 | PASS |
