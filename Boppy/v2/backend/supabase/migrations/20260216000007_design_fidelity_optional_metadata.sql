-- Optional metadata for Stitch fidelity surfaces.

alter table if exists public.profiles
    add column if not exists avatar_url text,
    add column if not exists driver_availability text,
    add column if not exists driver_rating double precision,
    add column if not exists driver_trip_count integer,
    add column if not exists last_lat double precision,
    add column if not exists last_lng double precision;

alter table if exists public.posts
    add column if not exists slot_remaining integer,
    add column if not exists slot_label text,
    add column if not exists hero_subtitle text,
    add column if not exists hero_aspect_ratio double precision;

alter table if exists public.inventory_items
    add column if not exists thumbnail_url text,
    add column if not exists category text,
    add column if not exists show_in_catalog boolean;

alter table if exists public.order_requests
    add column if not exists external_ref text,
    add column if not exists summary_title text,
    add column if not exists summary_image_url text,
    add column if not exists summary_total_cents integer,
    add column if not exists summary_eta_text text;

create index if not exists idx_profiles_driver_availability on public.profiles (driver_availability);
create index if not exists idx_order_requests_external_ref on public.order_requests (external_ref);
create index if not exists idx_inventory_items_category on public.inventory_items (category);
