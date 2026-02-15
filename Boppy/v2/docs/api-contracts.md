# API Contracts

All edge functions return:

```json
{
  "success": true,
  "data": {},
  "error": null,
  "request_id": "uuid"
}
```

Error form:

```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "error_code",
    "message": "human readable"
  },
  "request_id": "uuid"
}
```

## Endpoints

- `POST /functions/v1/create-invite`
- `POST /functions/v1/join-channel`
- `POST /functions/v1/create-order-request`
- `POST /functions/v1/update-order-status`
- `POST /functions/v1/assign-driver`
- `POST /functions/v1/build-route`
- `POST /functions/v1/reorder-route-stops`
- `POST /functions/v1/complete-stop`
- `POST /functions/v1/inventory-upsert-item`
- `POST /functions/v1/inventory-upsert-variant`
- `POST /functions/v1/inventory-adjust-stock`
- `POST /functions/v1/inventory-list`
- `POST /functions/v1/order-upsert-line-items`
- `POST /functions/v1/admin-archive-channel`
- `POST /functions/v1/admin-delete-order`
- `POST /functions/v1/admin-unassign-driver`
- `POST /functions/v1/admin-driver-memberships-upsert`
- `POST /functions/v1/admin-audit-events-list`
- `POST /functions/v1/admin-orders-list`
- `POST /functions/v1/admin-channel-members-list`
- `POST /functions/v1/admin-order-line-items-list`
- `POST /functions/v1/admin-routes-list`
- `POST /functions/v1/admin-member-role-upsert`
- `POST /functions/v1/admin-revoke-invite`
- `POST /functions/v1/admin-dashboard-summary`

## Role Authorization

- Owner: channel management, posting, quote/status update, driver assignment, route creation
- Driver: assigned orders/routes and stop completion
- Follower: read joined channel posts, create own order requests, read own order statuses
- Anonymous: invite token validation and OTP flow pre-join only
- `inventory-list` supports owner and driver read access for channel inventory visibility; inventory mutation endpoints remain owner-only.

## Client Contract Notes

- iOS runtime contracts are implemented in:
  - `/Users/jesse/pulse/Boppy/v2/ios/BoppyV2App/Sources/Core/Protocols/ServiceProtocols.swift`
  - `/Users/jesse/pulse/Boppy/v2/ios/BoppyV2App/Sources/App/Services/LiveSupabaseBackend.swift`
- Admin web typed edge client layer lives in:
  - `/Users/jesse/pulse/beambox-admin-web/src/lib/api/types.ts`
  - `/Users/jesse/pulse/beambox-admin-web/src/lib/api/client.ts`
  - `/Users/jesse/pulse/beambox-admin-web/src/lib/api/inventory.ts`
  - `/Users/jesse/pulse/beambox-admin-web/src/lib/api/orders.ts`
  - `/Users/jesse/pulse/beambox-admin-web/src/lib/api/admin.ts`

## Operational Guards

- `update-order-status` enforces legal transitions and returns `409` with code `invalid_status_transition` when a transition is illegal.
- `update-order-status` now links order workflow to inventory: first transition into `accepted` reserves stock for inventory-linked line items; transition to `cancelled` restocks previously reserved units (idempotent via order-scoped ledger reasons).
- `assign-driver` enforces legal assignment states (`accepted`, `assigned`, `address_review`) and returns `409` with code `invalid_assignment_state` otherwise.
- `order-upsert-line-items` is replace-style upsert: existing line items for the order are deleted before inserting the submitted set, and it validates `item_id`/`variant_id` ownership against the order channel, returning `400 invalid_inventory_reference` on mismatch.
- `admin-delete-order` hard delete is policy-gated by `ALLOW_HARD_DELETE=true` and terminal status (`cancelled`/`delivered`), returning `403 hard_delete_disabled` or `409 hard_delete_not_allowed_for_status` when blocked.
- `admin-driver-memberships-upsert` and `admin-member-role-upsert` return `409 driver_has_active_orders` when removing/demoting a driver who still has active assigned orders.
- `admin-driver-memberships-upsert` performs role upsert semantics for existing members: `add` promotes `follower -> driver`, `remove` demotes `driver -> follower` (does not remove channel membership).
- Sensitive owner mutations now enforce server-side rate limits and return `429 rate_limited` when exceeded:
  - `create-invite`
  - `update-order-status`
  - `inventory-adjust-stock`
  - `admin-archive-channel`
  - `admin-delete-order`
- `create-invite` now appends `invite_created` admin audit events.
- `update-order-status` now appends `order_status_updated` admin audit events in addition to immutable order ledger events.
