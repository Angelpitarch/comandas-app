-- 0001: estructura de tablas de Comandas (exportada del proyecto real).
-- Es segura de ejecutar varias veces: no toca tablas que ya existen.

create sequence if not exists public.ticket_number_seq;

create table if not exists public.app_config (
  id integer not null default 1 primary key,
  rate numeric not null default 36.5,
  updated_at timestamptz default now(),
  business_name text not null default 'Puesto de Comida',
  motiv_shown boolean not null default false
);

create table if not exists public.app_users (
  id uuid not null default gen_random_uuid() primary key,
  name text not null default '',
  pin text not null,
  role text not null default 'mesero',
  active boolean not null default true,
  created_at timestamptz default now(),
  pin_hash text,
  email text
);

create table if not exists public.categories (
  id uuid not null default gen_random_uuid() primary key,
  key text not null unique,
  label text not null,
  emoji text not null default '🍽️',
  "position" integer not null default 100,
  protected boolean not null default false
);

create table if not exists public.products (
  id uuid not null default gen_random_uuid() primary key,
  name text not null,
  emoji text default '🍽️',
  category text not null default 'otros',
  price numeric not null default 0,
  currency text not null default 'usd',
  available boolean not null default true,
  sizes jsonb not null default '[]'::jsonb,
  extras jsonb not null default '[]'::jsonb,
  quita jsonb not null default '[]'::jsonb,
  updated_at timestamptz default now(),
  stock numeric not null default 0,
  min_stock numeric not null default 0,
  track_stock boolean not null default false,
  recipe jsonb not null default '[]'::jsonb,
  combo_items jsonb not null default '[]'::jsonb
);

create table if not exists public.ingredients (
  id uuid not null default gen_random_uuid() primary key,
  name text not null,
  unit text not null default 'unidad',
  stock numeric not null default 0,
  min_stock numeric not null default 0,
  updated_at timestamptz default now(),
  cost numeric not null default 0,
  cost_currency text not null default 'usd',
  kind text not null default 'comida',
  emoji text not null default '📦'
);

create table if not exists public.dining_tables (
  number integer not null primary key,
  capacity integer not null default 2,
  status text not null default 'disponible',
  waiter text,
  opened_at timestamptz
);

create table if not exists public.takeaways (
  id uuid not null default gen_random_uuid() primary key,
  name text not null default '',
  status text not null default 'abierta',
  created_at timestamptz default now()
);

create table if not exists public.tickets (
  id uuid not null default gen_random_uuid() primary key,
  number integer not null default nextval('public.ticket_number_seq'::regclass),
  table_number integer,
  waiter text,
  status text not null default 'nueva',
  adicion boolean not null default false,
  note text,
  lines jsonb not null default '[]'::jsonb,
  reprinted boolean not null default false,
  sent_at timestamptz default now(),
  takeaway_id uuid,
  takeaway_name text
);

create table if not exists public.account_items (
  id uuid not null default gen_random_uuid() primary key,
  table_number integer,
  product_name text not null,
  qty integer not null default 1,
  size text,
  extras jsonb not null default '[]'::jsonb,
  quita jsonb not null default '[]'::jsonb,
  note text,
  unit_usd numeric not null default 0,
  created_at timestamptz default now(),
  takeaway_id uuid,
  ticket_id uuid
);

create table if not exists public.sales (
  id uuid not null default gen_random_uuid() primary key,
  table_number integer,
  total_usd numeric not null default 0,
  lines jsonb not null default '[]'::jsonb,
  payments jsonb not null default '[]'::jsonb,
  at timestamptz default now(),
  customer text
);

create table if not exists public.cancellations (
  id uuid not null default gen_random_uuid() primary key,
  ticket_number integer,
  table_number integer,
  takeaway_name text,
  reason text,
  merchandise_used boolean not null default false,
  value_usd numeric not null default 0,
  by_user text,
  at timestamptz default now()
);

create table if not exists public.cash_closes (
  id uuid not null default gen_random_uuid() primary key,
  closed_at timestamptz not null default now(),
  from_at timestamptz,
  total_usd numeric not null default 0,
  accounts_count integer not null default 0,
  by_method jsonb not null default '{}'::jsonb,
  units jsonb not null default '{}'::jsonb
);

create table if not exists public.employees (
  id uuid not null default gen_random_uuid() primary key,
  name text not null default '',
  cedula text,
  birthdate text,
  phone text,
  address text,
  "position" text,
  schedule text,
  salary numeric not null default 0,
  deductions numeric not null default 0,
  notes text,
  active boolean not null default true,
  created_at timestamptz default now()
);

create table if not exists public.gastos (
  id uuid not null default gen_random_uuid() primary key,
  concept text not null,
  category text not null default 'otros',
  amount_usd numeric not null default 0,
  payment_method text,
  note text,
  by_user text,
  at timestamptz not null default now()
);

-- Seguridad a nivel de fila activada en todas las tablas (las reglas estan en 0002).
alter table public.app_config enable row level security;
alter table public.app_users enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.ingredients enable row level security;
alter table public.dining_tables enable row level security;
alter table public.takeaways enable row level security;
alter table public.tickets enable row level security;
alter table public.account_items enable row level security;
alter table public.sales enable row level security;
alter table public.cancellations enable row level security;
alter table public.cash_closes enable row level security;
alter table public.employees enable row level security;
alter table public.gastos enable row level security;

-- Tiempo real: la app escucha cambios en estas tablas.
do $$
declare t text;
begin
  foreach t in array array['account_items','app_config','app_users','cancellations','cash_closes',
                           'categories','dining_tables','employees','gastos','ingredients','products',
                           'sales','takeaways','tickets']
  loop
    if not exists (select 1 from pg_publication_tables
                   where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
