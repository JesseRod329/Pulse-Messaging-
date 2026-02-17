create extension if not exists pgcrypto;

create type public.app_role as enum ('owner', 'driver', 'follower');
create type public.post_type as enum ('text', 'image', 'video');
create type public.order_status as enum (
  'requested',
  'quoted',
  'accepted',
  'assigned',
  'out_for_delivery',
  'delivered',
  'cancelled',
  'address_review'
);
create type public.route_status as enum ('planned', 'in_progress', 'completed', 'cancelled');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  phone_e164 text not null unique,
  display_name text,
  created_at timestamptz not null default now()
);

create table public.channels (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete restrict,
  title text not null,
  description text not null default '',
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.channel_memberships (
  channel_id uuid not null references public.channels(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role public.app_role not null,
  joined_at timestamptz not null default now(),
  primary key (channel_id, user_id)
);

create table public.channel_invites (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references public.channels(id) on delete cascade,
  token text not null unique,
  expires_at timestamptz not null,
  max_uses integer,
  uses_count integer not null default 0 check (uses_count >= 0),
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now()
);

create table public.posts (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references public.channels(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete restrict,
  post_type public.post_type not null,
  caption text,
  media_path text,
  created_at timestamptz not null default now(),
  archived_at timestamptz,
  check (
    (post_type = 'text' and media_path is null)
    or (post_type in ('image', 'video') and media_path is not null)
  )
);

create table public.order_requests (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references public.channels(id) on delete cascade,
  post_id uuid not null references public.posts(id) on delete restrict,
  customer_id uuid not null references public.profiles(id) on delete restrict,
  customer_phone text not null,
  delivery_address_json jsonb not null,
  lat double precision,
  lng double precision,
  quote_note text,
  status public.order_status not null default 'requested',
  assigned_driver_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.order_ledger_events (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.order_requests(id) on delete cascade,
  actor_id uuid not null references public.profiles(id) on delete restrict,
  event_type text not null,
  event_payload_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table public.delivery_routes (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references public.channels(id) on delete cascade,
  driver_id uuid not null references public.profiles(id) on delete restrict,
  status public.route_status not null default 'planned',
  approximate boolean not null default false,
  created_at timestamptz not null default now(),
  started_at timestamptz,
  completed_at timestamptz
);

create table public.delivery_route_stops (
  id uuid primary key default gen_random_uuid(),
  route_id uuid not null references public.delivery_routes(id) on delete cascade,
  order_id uuid not null references public.order_requests(id) on delete cascade,
  stop_index integer not null check (stop_index >= 0),
  eta_minutes integer,
  completed_at timestamptz,
  unique (route_id, stop_index),
  unique (route_id, order_id)
);

create index idx_channels_owner_id on public.channels(owner_id);
create index idx_channel_memberships_user_id on public.channel_memberships(user_id);
create index idx_channel_invites_channel_id on public.channel_invites(channel_id);
create index idx_channel_invites_token on public.channel_invites(token);
create index idx_posts_channel_id_created_at on public.posts(channel_id, created_at desc);
create index idx_order_requests_channel_id_status on public.order_requests(channel_id, status);
create index idx_order_requests_customer_id on public.order_requests(customer_id);
create index idx_order_requests_driver_id on public.order_requests(assigned_driver_id);
create index idx_order_ledger_events_order_id_created_at on public.order_ledger_events(order_id, created_at);
create index idx_delivery_routes_driver_id_status on public.delivery_routes(driver_id, status);
create index idx_delivery_route_stops_route_id on public.delivery_route_stops(route_id);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger trg_order_requests_touch_updated_at
before update on public.order_requests
for each row
execute function public.touch_updated_at();

create or replace function public.append_order_ledger_event(
  p_order_id uuid,
  p_actor_id uuid,
  p_event_type text,
  p_payload jsonb default '{}'::jsonb
)
returns public.order_ledger_events
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event public.order_ledger_events;
begin
  insert into public.order_ledger_events (order_id, actor_id, event_type, event_payload_json)
  values (p_order_id, p_actor_id, p_event_type, coalesce(p_payload, '{}'::jsonb))
  returning * into v_event;

  return v_event;
end;
$$;

create or replace function public.seed_initial_order_ledger_event()
returns trigger
language plpgsql
as $$
begin
  perform public.append_order_ledger_event(
    new.id,
    new.customer_id,
    'order_requested',
    jsonb_build_object('status', new.status)
  );
  return new;
end;
$$;

create trigger trg_order_requests_seed_ledger
after insert on public.order_requests
for each row
execute function public.seed_initial_order_ledger_event();
