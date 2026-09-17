-- PartMo admin-controlled fulfilment fields and audit trail.
-- Safe to run more than once in Supabase SQL Editor.

alter table public.orders add column if not exists courier_name text not null default '';
alter table public.orders add column if not exists tracking_number text not null default '';
alter table public.orders add column if not exists estimated_delivery date;
alter table public.orders add column if not exists status_note text not null default '';
alter table public.orders add column if not exists admin_note text not null default '';

create table if not exists public.order_status_history (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  status text not null,
  note text not null default '',
  changed_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

alter table public.order_status_history enable row level security;

drop policy if exists "Admins can view all order items"
  on public.order_items;
create policy "Admins can view all order items"
  on public.order_items for select
  using (auth.jwt() ->> 'email' = 'admin@precisionparts.com');

drop policy if exists "Users can view own order history"
  on public.order_status_history;
drop policy if exists "Admins can manage order history"
  on public.order_status_history;

create policy "Users can view own order history"
  on public.order_status_history for select
  using (exists (
    select 1 from public.orders
    where orders.id = order_status_history.order_id
      and orders.user_id = auth.uid()
  ));

create policy "Admins can manage order history"
  on public.order_status_history for all
  using (auth.jwt() ->> 'email' = 'admin@precisionparts.com')
  with check (auth.jwt() ->> 'email' = 'admin@precisionparts.com');

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'orders'
  ) then
    alter publication supabase_realtime add table public.orders;
  end if;
end $$;
