create index if not exists idx_delivery_route_stops_route_id_uncompleted on public.delivery_route_stops (route_id, completed_at) where completed_at is null;
