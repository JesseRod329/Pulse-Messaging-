create or replace function public.is_channel_owner(
  p_channel_id uuid,
  p_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.channels c
    where c.id = p_channel_id
      and c.owner_id = p_user_id
  );
$$;

alter table public.inventory_items enable row level security;
alter table public.inventory_item_variants enable row level security;
alter table public.inventory_stock_ledger enable row level security;
alter table public.order_line_items enable row level security;
alter table public.admin_audit_events enable row level security;

create policy "inventory_items_select_channel_member"
on public.inventory_items
for select
using (public.has_channel_role(channel_id));

create policy "inventory_items_insert_owner"
on public.inventory_items
for insert
with check (
  owner_id = auth.uid()
  and public.is_channel_owner(channel_id)
);

create policy "inventory_items_update_owner"
on public.inventory_items
for update
using (public.is_channel_owner(channel_id))
with check (public.is_channel_owner(channel_id));

create policy "inventory_items_delete_owner"
on public.inventory_items
for delete
using (public.is_channel_owner(channel_id));

create policy "inventory_variants_select_channel_member"
on public.inventory_item_variants
for select
using (
  exists (
    select 1
    from public.inventory_items i
    where i.id = item_id
      and public.has_channel_role(i.channel_id)
  )
);

create policy "inventory_variants_mutate_owner"
on public.inventory_item_variants
for all
using (
  exists (
    select 1
    from public.inventory_items i
    where i.id = item_id
      and public.is_channel_owner(i.channel_id)
  )
)
with check (
  exists (
    select 1
    from public.inventory_items i
    where i.id = item_id
      and public.is_channel_owner(i.channel_id)
  )
);

create policy "inventory_stock_ledger_select_owner_or_driver"
on public.inventory_stock_ledger
for select
using (
  public.is_channel_owner(channel_id)
  or public.has_channel_role(channel_id, array['driver']::public.app_role[])
);

create policy "inventory_stock_ledger_insert_owner"
on public.inventory_stock_ledger
for insert
with check (public.is_channel_owner(channel_id));

create policy "order_line_items_select_order_visible"
on public.order_line_items
for select
using (
  exists (
    select 1
    from public.order_requests o
    where o.id = order_id
      and (
        o.customer_id = auth.uid()
        or o.assigned_driver_id = auth.uid()
        or public.is_channel_owner(o.channel_id)
      )
  )
);

create policy "order_line_items_mutate_owner"
on public.order_line_items
for all
using (
  exists (
    select 1
    from public.order_requests o
    where o.id = order_id
      and public.is_channel_owner(o.channel_id)
  )
)
with check (
  exists (
    select 1
    from public.order_requests o
    where o.id = order_id
      and public.is_channel_owner(o.channel_id)
  )
);

create policy "admin_audit_select_owner"
on public.admin_audit_events
for select
using (public.is_channel_owner(channel_id));

create policy "admin_audit_insert_owner"
on public.admin_audit_events
for insert
with check (public.is_channel_owner(channel_id));
