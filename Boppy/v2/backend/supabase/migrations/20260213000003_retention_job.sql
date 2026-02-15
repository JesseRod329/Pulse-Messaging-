create or replace function public.purge_expired_order_data(
  p_keep interval default interval '12 months'
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_deleted integer := 0;
begin
  with doomed as (
    select id
    from public.order_requests
    where created_at < now() - p_keep
      and status in ('delivered', 'cancelled')
  ), deleted as (
    delete from public.order_requests o
    using doomed d
    where o.id = d.id
    returning 1
  )
  select count(*) into v_deleted from deleted;

  return v_deleted;
end;
$$;

-- Optional scheduler on Supabase instances where pg_cron is enabled.
do $$
begin
  begin
    create extension if not exists pg_cron;
  exception
    when others then
      -- Extension may be managed externally.
      null;
  end;

  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    begin
      perform cron.schedule(
        'boppy_v2_purge_expired_order_data',
        '17 3 * * *',
        $job$select public.purge_expired_order_data(interval '12 months');$job$
      );
    exception
      when unique_violation then
        -- Job already exists.
        null;
      when others then
        null;
    end;
  end if;
end;
$$;
