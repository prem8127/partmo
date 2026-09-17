-- ═══════════════════════════════════════════════════════════════════════════
-- Precision Parts — Supabase Database Migration
-- Run this in: Supabase Dashboard → SQL Editor → New Query
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. PROFILES ───────────────────────────────────────────────────────────
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  full_name   text,
  phone       text,
  avatar_url  text,
  created_at  timestamptz default now()
);

alter table public.profiles enable row level security;

drop policy if exists "Users can view own profile" on public.profiles;
drop policy if exists "Users can upsert own profile" on public.profiles;
drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can view own profile"    on public.profiles for select using (auth.uid() = id);
create policy "Users can upsert own profile"  on public.profiles for insert with check (auth.uid() = id);
create policy "Users can update own profile"  on public.profiles for update using (auth.uid() = id);

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, new.raw_user_meta_data ->> 'full_name');
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ── 2. PRODUCTS ───────────────────────────────────────────────────────────
create table if not exists public.products (
  id              uuid primary key default gen_random_uuid(),
  name            text not null,
  category        text not null default '',
  price           numeric not null default 0,
  mrp             numeric not null default 0,
  rating          numeric not null default 4.5,
  review_count    int not null default 0,
  stock           int not null default 0,
  image_url       text not null default '',
  image_urls      text[] not null default '{}',
  badge           text not null default '',
  description     text not null default '',
  compatibility   text[] not null default '{}',
  specs           jsonb not null default '{}',
  created_at      timestamptz default now()
);

alter table public.products add column if not exists image_urls text[] not null default '{}';

alter table public.products enable row level security;

drop policy if exists "Anyone can view products" on public.products;
drop policy if exists "Admins can insert products" on public.products;
drop policy if exists "Admins can update products" on public.products;
drop policy if exists "Admins can delete products" on public.products;
create policy "Anyone can view products"      on public.products for select using (true);
create policy "Admins can insert products"    on public.products for insert with check (auth.jwt() ->> 'email' = 'admin@precisionparts.com');
create policy "Admins can update products"    on public.products for update using (auth.jwt() ->> 'email' = 'admin@precisionparts.com');
create policy "Admins can delete products"    on public.products for delete using (auth.jwt() ->> 'email' = 'admin@precisionparts.com');

-- ── 3. USER ADDRESSES ─────────────────────────────────────────────────────
create table if not exists public.user_addresses (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  label       text not null default 'Home',
  name        text not null,
  line        text not null,
  city        text not null,
  state       text not null default '',
  pincode     text not null default '',
  phone       text not null,
  alternate_phone text not null default '',
  is_default  boolean not null default false,
  created_at  timestamptz default now()
);

alter table public.user_addresses add column if not exists alternate_phone text not null default '';

alter table public.user_addresses enable row level security;

drop policy if exists "Users can manage own addresses" on public.user_addresses;
create policy "Users can manage own addresses" on public.user_addresses
  for all using (auth.uid() = user_id);

-- ── 4. ORDERS ─────────────────────────────────────────────────────────────
create table if not exists public.orders (
  id              uuid primary key default gen_random_uuid(),
  order_ref       text unique,
  user_id         uuid not null references auth.users(id) on delete cascade,
  status          text not null default 'confirmed',
  subtotal        numeric not null default 0,
  tax             numeric not null default 0,
  total           numeric not null default 0,
  address_id      uuid references public.user_addresses(id),
  payment_method  text not null default 'cod',
  whatsapp_number text not null default '',
  alternate_whatsapp_number text not null default '',
  delivery_address text not null default '',
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);

-- Keep existing deployments compatible when this migration is re-run.
alter table public.orders add column if not exists order_ref text;
alter table public.orders add column if not exists whatsapp_number text not null default '';
alter table public.orders add column if not exists alternate_whatsapp_number text not null default '';
alter table public.orders add column if not exists delivery_address text not null default '';
alter table public.orders add column if not exists courier_name text not null default '';
alter table public.orders add column if not exists tracking_number text not null default '';
alter table public.orders add column if not exists estimated_delivery date;
alter table public.orders add column if not exists status_note text not null default '';
alter table public.orders add column if not exists admin_note text not null default '';
create unique index if not exists idx_orders_order_ref on public.orders(order_ref);

alter table public.orders enable row level security;

drop policy if exists "Users can view own orders" on public.orders;
drop policy if exists "Users can insert own orders" on public.orders;
drop policy if exists "Admins can view all orders" on public.orders;
drop policy if exists "Admins can update order status" on public.orders;
create policy "Users can view own orders"     on public.orders for select using (auth.uid() = user_id);
create policy "Users can insert own orders"   on public.orders for insert with check (auth.uid() = user_id);
create policy "Admins can view all orders"    on public.orders for select using (auth.jwt() ->> 'email' = 'admin@precisionparts.com');
create policy "Admins can update order status" on public.orders for update using (auth.jwt() ->> 'email' = 'admin@precisionparts.com');

create table if not exists public.order_status_history (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  status text not null,
  note text not null default '',
  changed_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);
alter table public.order_status_history enable row level security;
drop policy if exists "Users can view own order history" on public.order_status_history;
drop policy if exists "Admins can manage order history" on public.order_status_history;
create policy "Users can view own order history" on public.order_status_history
  for select using (exists (
    select 1 from public.orders
    where orders.id = order_status_history.order_id
      and orders.user_id = auth.uid()
  ));
create policy "Admins can manage order history" on public.order_status_history
  for all using (auth.jwt() ->> 'email' = 'admin@precisionparts.com')
  with check (auth.jwt() ->> 'email' = 'admin@precisionparts.com');

-- Push admin status changes to the customer's tracking screen in real time.
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

-- ── 5. ORDER ITEMS ────────────────────────────────────────────────────────
create table if not exists public.order_items (
  id            uuid primary key default gen_random_uuid(),
  order_id      uuid not null references public.orders(id) on delete cascade,
  product_id    uuid references public.products(id),
  product_name  text not null,
  quantity      int not null default 1,
  unit_price    numeric not null default 0
);

alter table public.order_items enable row level security;

drop policy if exists "Users can view own order items" on public.order_items;
drop policy if exists "Admins can view all order items" on public.order_items;
create policy "Users can view own order items" on public.order_items
  for select using (
    exists (
      select 1 from public.orders
      where orders.id = order_items.order_id
        and orders.user_id = auth.uid()
    )
  );
create policy "Admins can view all order items" on public.order_items
  for select using (auth.jwt() ->> 'email' = 'admin@precisionparts.com');

drop policy if exists "Users can insert order items" on public.order_items;
create policy "Users can insert order items" on public.order_items
  for insert with check (
    exists (
      select 1 from public.orders
      where orders.id = order_items.order_id
        and orders.user_id = auth.uid()
    )
  );

-- ── 6. WISHLIST ───────────────────────────────────────────────────────────
create table if not exists public.wishlist (
  user_id     uuid not null references auth.users(id) on delete cascade,
  product_id  uuid not null references public.products(id) on delete cascade,
  created_at  timestamptz default now(),
  primary key (user_id, product_id)
);

alter table public.wishlist enable row level security;

drop policy if exists "Users can manage own wishlist" on public.wishlist;
create policy "Users can manage own wishlist" on public.wishlist
  for all using (auth.uid() = user_id);

-- ── 7. REVIEWS ────────────────────────────────────────────────────────────
create table if not exists public.reviews (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  product_id  uuid not null references public.products(id) on delete cascade,
  rating      int not null check (rating between 1 and 5),
  comment     text not null default '',
  created_at  timestamptz default now(),
  unique (user_id, product_id)
);

alter table public.reviews enable row level security;

drop policy if exists "Anyone can view reviews" on public.reviews;
drop policy if exists "Users can submit own reviews" on public.reviews;
drop policy if exists "Users can update own reviews" on public.reviews;
create policy "Anyone can view reviews"       on public.reviews for select using (true);
create policy "Users can submit own reviews"  on public.reviews for insert with check (auth.uid() = user_id);
create policy "Users can update own reviews"  on public.reviews for update using (auth.uid() = user_id);

-- ── 8. STORAGE BUCKETS ───────────────────────────────────────────────────
-- Run in Supabase Dashboard > Storage if not using this SQL:
-- insert into storage.buckets (id, name, public) values ('product-images', 'product-images', true);
-- insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true);

-- ── 9. INDEXES ────────────────────────────────────────────────────────────
create index if not exists idx_products_category  on public.products(category);
create index if not exists idx_orders_user_id     on public.orders(user_id);
create index if not exists idx_order_items_order  on public.order_items(order_id);
create index if not exists idx_wishlist_user      on public.wishlist(user_id);
create index if not exists idx_reviews_product    on public.reviews(product_id);
