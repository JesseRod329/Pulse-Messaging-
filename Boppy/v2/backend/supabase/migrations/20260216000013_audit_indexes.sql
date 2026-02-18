create index if not exists idx_admin_audit_events_actor_id_created_at on public.admin_audit_events (actor_id, created_at desc);
