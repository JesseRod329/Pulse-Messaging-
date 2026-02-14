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

## Role Authorization

- Owner: channel management, posting, quote/status update, driver assignment, route creation
- Driver: assigned orders/routes and stop completion
- Follower: read joined channel posts, create own order requests, read own order statuses
- Anonymous: invite token validation and OTP flow pre-join only

## Planned Endpoints (V1.5)

- `POST /functions/v1/inventory-upsert-item`
- `POST /functions/v1/inventory-adjust-stock`
- `GET /functions/v1/inventory-list`
- `POST /functions/v1/admin-archive-channel`
- `POST /functions/v1/admin-delete-order` (policy-gated, audit-required)
