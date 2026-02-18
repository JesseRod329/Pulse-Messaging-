create or replace function public.restock_order_inventory_atomic(
  p_order_id uuid,
  p_actor_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order_channel_id uuid;
  v_reserve_reason text;
  v_restock_reason text;
  v_entities integer := 0;
  v_units integer := 0;
  v_next integer;
  v_variant_demand record;
  v_variant_row record;
  v_item_demand record;
  v_item_row record;
begin
  select channel_id
    into v_order_channel_id
  from public.order_requests
  where id = p_order_id
  for update;

  if not found then
    raise exception 'order_not_found';
  end if;

  v_reserve_reason := format('order_reserved:%s', p_order_id);
  v_restock_reason := format('order_cancel_restock:%s', p_order_id);

  if not exists (
    select 1
    from public.inventory_stock_ledger
    where channel_id = v_order_channel_id
      and reason = v_reserve_reason
    limit 1
  ) then
    return null;
  end if;

  if exists (
    select 1
    from public.inventory_stock_ledger
    where channel_id = v_order_channel_id
      and reason = v_restock_reason
    limit 1
  ) then
    return null;
  end if;

  for v_variant_demand in
    select
      li.variant_id,
      sum(li.quantity)::integer as qty
    from public.order_line_items li
    where li.order_id = p_order_id
      and li.variant_id is not null
    group by li.variant_id
  loop
    select
      v.id,
      v.item_id,
      v.stock_on_hand
    into v_variant_row
    from public.inventory_item_variants v
    where v.id = v_variant_demand.variant_id
    for update;

    if not found then
      raise exception 'inventory_reference_missing:variant:%', v_variant_demand.variant_id;
    end if;

    perform 1
    from public.inventory_items i
    where i.id = v_variant_row.item_id
      and i.channel_id = v_order_channel_id
    for update;

    if not found then
      raise exception 'inventory_reference_missing:item:%', v_variant_row.item_id;
    end if;

    v_next := v_variant_row.stock_on_hand + v_variant_demand.qty;

    update public.inventory_item_variants
    set stock_on_hand = v_next
    where id = v_variant_row.id;

    insert into public.inventory_stock_ledger (
      channel_id,
      item_id,
      variant_id,
      actor_id,
      delta,
      balance_after,
      reason,
      metadata_json
    )
    values (
      v_order_channel_id,
      v_variant_row.item_id,
      v_variant_row.id,
      p_actor_id,
      v_variant_demand.qty,
      v_next,
      v_restock_reason,
      jsonb_build_object(
        'event_kind', 'order_inventory_restocked',
        'order_id', p_order_id
      )
    );

    v_entities := v_entities + 1;
    v_units := v_units + v_variant_demand.qty;
  end loop;

  for v_item_demand in
    select
      li.item_id,
      sum(li.quantity)::integer as qty
    from public.order_line_items li
    where li.order_id = p_order_id
      and li.variant_id is null
      and li.item_id is not null
    group by li.item_id
  loop
    select
      i.id,
      i.stock_on_hand
    into v_item_row
    from public.inventory_items i
    where i.id = v_item_demand.item_id
      and i.channel_id = v_order_channel_id
    for update;

    if not found then
      raise exception 'inventory_reference_missing:item:%', v_item_demand.item_id;
    end if;

    v_next := v_item_row.stock_on_hand + v_item_demand.qty;

    update public.inventory_items
    set stock_on_hand = v_next
    where id = v_item_row.id;

    insert into public.inventory_stock_ledger (
      channel_id,
      item_id,
      variant_id,
      actor_id,
      delta,
      balance_after,
      reason,
      metadata_json
    )
    values (
      v_order_channel_id,
      v_item_row.id,
      null,
      p_actor_id,
      v_item_demand.qty,
      v_next,
      v_restock_reason,
      jsonb_build_object(
        'event_kind', 'order_inventory_restocked',
        'order_id', p_order_id
      )
    );

    v_entities := v_entities + 1;
    v_units := v_units + v_item_demand.qty;
  end loop;

  if v_entities = 0 then
    return null;
  end if;

  perform public.log_admin_audit_event(
    v_order_channel_id,
    p_actor_id,
    'order_inventory_restocked',
    'order_request',
    p_order_id::text,
    null,
    jsonb_build_object(
      'entities_adjusted', v_entities,
      'units_adjusted', v_units
    )
  );

  return jsonb_build_object(
    'event', 'order_inventory_restocked',
    'reason', v_restock_reason,
    'entities_adjusted', v_entities,
    'units_adjusted', v_units
  );
end;
$$;
