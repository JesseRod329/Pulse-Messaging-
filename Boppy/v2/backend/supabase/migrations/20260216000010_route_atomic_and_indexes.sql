create or replace function public.build_delivery_route(
  p_channel_id uuid,
  p_driver_id uuid,
  p_actor_id uuid,
  p_order_ids uuid[],
  p_etas integer[],
  p_approximate boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_route public.delivery_routes;
  v_route_stops jsonb := '[]'::jsonb;
  v_count integer;
  v_distinct_count integer;
  v_locked_count integer := 0;
  v_idx integer;
  v_order_id uuid;
begin
  v_count := coalesce(array_length(p_order_ids, 1), 0);
  if v_count = 0 then
    raise exception 'no_routable_orders';
  end if;

  if coalesce(array_length(p_etas, 1), 0) <> v_count then
    raise exception 'invalid_request:etas_mismatch';
  end if;

  select count(distinct o)
    into v_distinct_count
  from unnest(p_order_ids) as o;

  if v_distinct_count <> v_count then
    raise exception 'invalid_request:duplicate_order_ids';
  end if;

  for v_order_id in
    select o.id
    from public.order_requests o
    where o.id = any(p_order_ids)
      and o.channel_id = p_channel_id
      and o.assigned_driver_id = p_driver_id
      and o.status in ('assigned', 'accepted', 'quoted')
    for update
  loop
    v_locked_count := v_locked_count + 1;
  end loop;

  if v_locked_count <> v_count then
    raise exception 'no_routable_orders';
  end if;

  insert into public.delivery_routes (
    channel_id,
    driver_id,
    status,
    approximate
  )
  values (
    p_channel_id,
    p_driver_id,
    'planned',
    coalesce(p_approximate, false)
  )
  returning * into v_route;

  for v_idx in 1..v_count loop
    insert into public.delivery_route_stops (
      route_id,
      order_id,
      stop_index,
      eta_minutes
    )
    values (
      v_route.id,
      p_order_ids[v_idx],
      v_idx - 1,
      p_etas[v_idx]
    );
  end loop;

  update public.order_requests
  set status = 'out_for_delivery'
  where id = any(p_order_ids);

  for v_idx in 1..v_count loop
    perform public.append_order_ledger_event(
      p_order_ids[v_idx],
      p_actor_id,
      'route_built',
      jsonb_build_object(
        'route_id', v_route.id,
        'approximate', coalesce(p_approximate, false)
      )
    );
  end loop;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'route_id', s.route_id,
        'order_id', s.order_id,
        'stop_index', s.stop_index,
        'eta_minutes', s.eta_minutes
      ) order by s.stop_index
    ),
    '[]'::jsonb
  )
  into v_route_stops
  from public.delivery_route_stops s
  where s.route_id = v_route.id;

  return jsonb_build_object(
    'route', jsonb_build_object(
      'id', v_route.id,
      'status', v_route.status,
      'approximate', v_route.approximate,
      'created_at', v_route.created_at
    ),
    'stops', v_route_stops
  );
end;
$$;
