# Supabase Backend (Boppy V2)

## Contents

- `migrations/` schema, RLS, and retention SQL
- `functions/` edge functions and shared utilities

## Apply Migrations

```bash
supabase db push
```

## Required Secrets

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `SUPABASE_ANON_KEY`
- `MAPBOX_ACCESS_TOKEN`

## Deploy Edge Functions

```bash
supabase functions deploy create-invite
supabase functions deploy join-channel
supabase functions deploy create-order-request
supabase functions deploy update-order-status
supabase functions deploy assign-driver
supabase functions deploy build-route
supabase functions deploy reorder-route-stops
supabase functions deploy complete-stop
supabase functions deploy inventory-upsert-item
supabase functions deploy inventory-upsert-variant
supabase functions deploy inventory-adjust-stock
supabase functions deploy inventory-list
supabase functions deploy order-upsert-line-items
supabase functions deploy admin-archive-channel
supabase functions deploy admin-delete-order
supabase functions deploy admin-unassign-driver
supabase functions deploy admin-driver-memberships-upsert
supabase functions deploy admin-audit-events-list
```
