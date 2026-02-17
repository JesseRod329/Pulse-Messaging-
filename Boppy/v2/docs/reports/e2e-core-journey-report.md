# E2E Core Journey Report

- Date: 2026-02-15 06:35:44 UTC
- Project: wgdzwtrzgmhzhyjyxdaf
- Channel: 5300f0ec-a1dd-4f99-8f7d-2883f44a31d9
- Order: bd749307-3401-450f-a9f5-b5c680bbb81c
- Route: 8b4887ab-2d0a-4a2a-b325-0f5f75433bb6

| Step | Expected | Actual | Status |
|---|---|---|---|
| Follower creates order request | order id returned | bd749307-3401-450f-a9f5-b5c680bbb81c (address_review) | PASS |
| Owner assigns driver | success | ok | PASS |
| Owner builds route | route id returned | 8b4887ab-2d0a-4a2a-b325-0f5f75433bb6 (ok) | PASS |
| Driver completes stop | success, remaining 0 | ok, remaining=0 | PASS |
| Order reaches delivered | delivered | delivered | PASS |
| Route reaches completed | completed | completed | PASS |
