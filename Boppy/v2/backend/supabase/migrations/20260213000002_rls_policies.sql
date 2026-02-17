create or replace function public.has_channel_role(
  p_channel_id uuid,
  p_roles public.app_role[] default null
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.channel_memberships m
    where m.channel_id = p_channel_id
      and m.user_id = auth.uid()
      and (p_roles is null or m.role = any(p_roles))
  );
$$;

alter table public.profiles enable row level security;
alter table public.channels enable row level security;
alter table public.channel_memberships enable row level security;
alter table public.channel_invites enable row level security;
alter table public.posts enable row level security;
alter table public.order_requests enable row level security;
alter table public.order_ledger_events enable row level security;
alter table public.delivery_routes enable row level security;
alter table public.delivery_route_stops enable row level security;

create policy "profiles_select_self"
on public.profiles
for select
using (id = auth.uid());

create policy "profiles_insert_self"
on public.profiles
for insert
with check (id = auth.uid());

create policy "profiles_update_self"
on public.profiles
for update
using (id = auth.uid())
with check (id = auth.uid());

create policy "channels_select_member"
on public.channels
for select
using (public.has_channel_role(id));

create policy "channels_insert_owner"
on public.channels
for insert
with check (owner_id = auth.uid());

create policy "channels_update_owner"
on public.channels
for update
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

create policy "channels_delete_owner"
on public.channels
for delete
using (owner_id = auth.uid());

create policy "channel_memberships_select_owner_or_self"
on public.channel_memberships
for select
using (
  user_id = auth.uid()
  or exists (
    select 1 from public.channels c
    where c.id = channel_id and c.owner_id = auth.uid()
  )
);

create policy "channel_memberships_insert_owner"
on public.channel_memberships
for insert
with check (
  exists (
    select 1 from public.channels c
    where c.id = channel_id and c.owner_id = auth.uid()
  )
);

create policy "channel_memberships_update_owner"
on public.channel_memberships
for update
using (
  exists (
    select 1 from public.channels c
    where c.id = channel_id and c.owner_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.channels c
    where c.id = channel_id and c.owner_id = auth.uid()
  )
);

create policy "channel_memberships_delete_owner"
on public.channel_memberships
for delete
using (
  exists (
    select 1 from public.channels c
    where c.id = channel_id and c.owner_id = auth.uid()
  )
);

create policy "channel_invites_owner_only"
on public.channel_invites
for all
using (
  exists (
    select 1 from public.channels c
    where c.id = channel_id and c.owner_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.channels c
    where c.id = channel_id and c.owner_id = auth.uid()
  )
);

create policy "posts_select_members"
on public.posts
for select
using (public.has_channel_role(channel_id));

create policy "posts_insert_owner"
on public.posts
for insert
with check (
  author_id = auth.uid()
  and public.has_channel_role(channel_id, array['owner']::public.app_role[])
);

create policy "posts_update_owner"
on public.posts
for update
using (
  author_id = auth.uid()
  and public.has_channel_role(channel_id, array['owner']::public.app_role[])
)
with check (
  author_id = auth.uid()
  and public.has_channel_role(channel_id, array['owner']::public.app_role[])
);

create policy "posts_delete_owner"
on public.posts
for delete
using (
  author_id = auth.uid()
  and public.has_channel_role(channel_id, array['owner']::public.app_role[])
);

create policy "orders_select_visible"
on public.order_requests
for select
using (
  customer_id = auth.uid()
  or assigned_driver_id = auth.uid()
  or exists (
    select 1 from public.channels c
    where c.id = channel_id and c.owner_id = auth.uid()
  )
);

create policy "orders_insert_follower"
on public.order_requests
for insert
with check (
  customer_id = auth.uid()
  and public.has_channel_role(channel_id, array['follower']::public.app_role[])
  and exists (
    select 1
    from public.posts p
    where p.id = post_id
      and p.channel_id = channel_id
  )
);

create policy "orders_update_owner_or_driver"
on public.order_requests
for update
using (
  assigned_driver_id = auth.uid()
  or exists (
    select 1 from public.channels c
    where c.id = channel_id and c.owner_id = auth.uid()
  )
)
with check (
  assigned_driver_id = auth.uid()
  or exists (
    select 1 from public.channels c
    where c.id = channel_id and c.owner_id = auth.uid()
  )
);

create policy "order_ledger_select_visible"
on public.order_ledger_events
for select
using (
  exists (
    select 1
    from public.order_requests o
    where o.id = order_id
      and (
        o.customer_id = auth.uid()
        or o.assigned_driver_id = auth.uid()
        or exists (
          select 1 from public.channels c
          where c.id = o.channel_id and c.owner_id = auth.uid()
        )
      )
  )
);

create policy "routes_select_owner_or_driver"
on public.delivery_routes
for select
using (
  driver_id = auth.uid()
  or exists (
    select 1 from public.channels c
    where c.id = channel_id and c.owner_id = auth.uid()
  )
);

create policy "routes_insert_owner"
on public.delivery_routes
for insert
with check (
  exists (
    select 1 from public.channels c
    where c.id = channel_id and c.owner_id = auth.uid()
  )
);

create policy "routes_update_owner_or_driver"
on public.delivery_routes
for update
using (
  driver_id = auth.uid()
  or exists (
    select 1 from public.channels c
    where c.id = channel_id and c.owner_id = auth.uid()
  )
)
with check (
  driver_id = auth.uid()
  or exists (
    select 1 from public.channels c
    where c.id = channel_id and c.owner_id = auth.uid()
  )
);

create policy "routes_delete_owner"
on public.delivery_routes
for delete
using (
  exists (
    select 1 from public.channels c
    where c.id = channel_id and c.owner_id = auth.uid()
  )
);

create policy "route_stops_select_owner_or_driver"
on public.delivery_route_stops
for select
using (
  exists (
    select 1
    from public.delivery_routes r
    left join public.channels c on c.id = r.channel_id
    where r.id = route_id
      and (r.driver_id = auth.uid() or c.owner_id = auth.uid())
  )
);

create policy "route_stops_insert_owner"
on public.delivery_route_stops
for insert
with check (
  exists (
    select 1
    from public.delivery_routes r
    join public.channels c on c.id = r.channel_id
    where r.id = route_id
      and c.owner_id = auth.uid()
  )
);

create policy "route_stops_update_owner_or_driver"
on public.delivery_route_stops
for update
using (
  exists (
    select 1
    from public.delivery_routes r
    left join public.channels c on c.id = r.channel_id
    where r.id = route_id
      and (r.driver_id = auth.uid() or c.owner_id = auth.uid())
  )
)
with check (
  exists (
    select 1
    from public.delivery_routes r
    left join public.channels c on c.id = r.channel_id
    where r.id = route_id
      and (r.driver_id = auth.uid() or c.owner_id = auth.uid())
  )
);

create policy "route_stops_delete_owner"
on public.delivery_route_stops
for delete
using (
  exists (
    select 1
    from public.delivery_routes r
    join public.channels c on c.id = r.channel_id
    where r.id = route_id
      and c.owner_id = auth.uid()
  )
);
