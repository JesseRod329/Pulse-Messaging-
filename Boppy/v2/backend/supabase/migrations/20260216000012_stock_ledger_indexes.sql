create index if not exists idx_inventory_stock_ledger_actor_id_created_at on public.inventory_stock_ledger (actor_id, created_at desc);
