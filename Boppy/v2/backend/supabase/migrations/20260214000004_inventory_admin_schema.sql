create table public.inventory_items (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references public.channels(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete restrict,
  name text not null,
  sku text not null,
  description text not null default '',
  default_price_cents integer not null check (default_price_cents >= 0),
  currency_code text not null default 'USD',
  track_stock boolean not null default true,
  stock_on_hand integer not null default 0 check (stock_on_hand >= 0),
  low_stock_threshold integer not null default 0 check (low_stock_threshold >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (channel_id, sku)
);

create table public.inventory_item_variants (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.inventory_items(id) on delete cascade,
  name text not null,
  sku text not null,
  price_cents integer not null check (price_cents >= 0),
  stock_on_hand integer not null default 0 check (stock_on_hand >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (item_id, sku)
);

create table public.inventory_stock_ledger (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references public.channels(id) on delete cascade,
  item_id uuid not null references public.inventory_items(id) on delete cascade,
  variant_id uuid references public.inventory_item_variants(id) on delete set null,
  actor_id uuid not null references public.profiles(id) on delete restrict,
  delta integer not null,
  balance_after integer not null check (balance_after >= 0),
  reason text not null,
  metadata_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table public.order_line_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.order_requests(id) on delete cascade,
  item_id uuid references public.inventory_items(id) on delete set null,
  variant_id uuid references public.inventory_item_variants(id) on delete set null,
  title text not null,
  sku text not null,
  quantity integer not null check (quantity > 0),
  unit_price_cents integer not null check (unit_price_cents >= 0),
  line_total_cents integer generated always as (quantity * unit_price_cents) stored,
  created_at timestamptz not null default now()
);

create table public.admin_audit_events (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references public.channels(id) on delete cascade,
  actor_id uuid not null references public.profiles(id) on delete restrict,
  action text not null,
  target_type text not null,
  target_id text not null,
  reason text,
  event_payload_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.order_requests
add column if not exists archived_at timestamptz;

create index idx_inventory_items_channel_id on public.inventory_items(channel_id);
create index idx_inventory_items_owner_id on public.inventory_items(owner_id);
create index idx_inventory_variants_item_id on public.inventory_item_variants(item_id);
create index idx_inventory_stock_ledger_item_id_created_at on public.inventory_stock_ledger(item_id, created_at desc);
create index idx_order_line_items_order_id on public.order_line_items(order_id);
create index idx_admin_audit_channel_id_created_at on public.admin_audit_events(channel_id, created_at desc);
create index idx_admin_audit_action on public.admin_audit_events(action);

create trigger trg_inventory_items_touch_updated_at
before update on public.inventory_items
for each row
execute function public.touch_updated_at();

create trigger trg_inventory_item_variants_touch_updated_at
before update on public.inventory_item_variants
for each row
execute function public.touch_updated_at();

create or replace function public.log_admin_audit_event(
  p_channel_id uuid,
  p_actor_id uuid,
  p_action text,
  p_target_type text,
  p_target_id text,
  p_reason text default null,
  p_payload jsonb default '{}'::jsonb
)
returns public.admin_audit_events
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event public.admin_audit_events;
begin
  insert into public.admin_audit_events (
    channel_id,
    actor_id,
    action,
    target_type,
    target_id,
    reason,
    event_payload_json
  )
  values (
    p_channel_id,
    p_actor_id,
    p_action,
    p_target_type,
    p_target_id,
    p_reason,
    coalesce(p_payload, '{}'::jsonb)
  )
  returning * into v_event;

  return v_event;
end;
$$;
