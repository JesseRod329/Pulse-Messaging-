create index if not exists idx_inventory_items_category on public.inventory_items (category);
create index if not exists idx_order_line_items_item_id on public.order_line_items (item_id);
