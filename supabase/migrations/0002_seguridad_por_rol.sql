-- 0002: seguridad por rol.
--   admin  -> todo (incluye pantallas de mesero y cocina)
--   mesero -> atender mesas: pedidos, cuentas, cobro, para llevar
--   cocina -> solo ver comandas y cambiar su estado
-- Es segura de ejecutar varias veces.

-- ---------------------------------------------------------------
-- 1) Ayudantes privados (el esquema "private" no se expone por la API)
-- ---------------------------------------------------------------
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

-- Rol del usuario con sesion abierta (null si no es personal activo de la app).
-- Se identifica por el correo de su cuenta de acceso = correo en app_users.
create or replace function private.staff_role()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select a.role
  from public.app_users a
  where a.active
    and lower(a.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  limit 1;
$$;
revoke all on function private.staff_role() from public, anon;
grant execute on function private.staff_role() to authenticated;

create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(private.staff_role() = 'admin', false);
$$;
revoke all on function private.is_admin() from public, anon;
grant execute on function private.is_admin() to authenticated;

-- ---------------------------------------------------------------
-- 2) Funciones de la app
-- ---------------------------------------------------------------
-- login_pin ya no existe: el acceso es correo + PIN con Supabase Auth.
drop function if exists public.login_pin(text);

-- Perfil real de quien inicio sesion (la app lo usa para decidir la pantalla).
create or replace function public.my_profile()
returns table(id uuid, name text, role text)
language sql
stable
security definer
set search_path = public
as $$
  select a.id, a.name, a.role
  from public.app_users a
  where a.active
    and lower(a.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  limit 1;
$$;

create or replace function public.save_user(p_id uuid, p_name text, p_pin text, p_role text, p_active boolean)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if not private.is_admin() then
    raise exception 'No autorizado' using errcode = '42501';
  end if;
  if p_role not in ('admin', 'cocina', 'mesero') then
    raise exception 'Rol invalido' using errcode = '22023';
  end if;
  if p_id is null then
    insert into app_users(name, pin, pin_hash, role, active)
      values (p_name, '', crypt(p_pin, gen_salt('bf')), p_role, p_active);
  else
    update app_users set name = p_name, role = p_role, active = p_active,
      pin_hash = case when coalesce(p_pin,'') <> '' then crypt(p_pin, gen_salt('bf')) else pin_hash end
    where id = p_id;
  end if;
end; $$;

create or replace function public.cambiar_pin(p_actual text, p_nuevo text)
returns text
language plpgsql
security definer
set search_path = extensions, public
as $$
declare
  uid  uuid := auth.uid();
  hash text;
begin
  if uid is null then
    return 'sin_sesion';
  end if;
  select encrypted_password into hash from auth.users where id = uid;
  if hash is null then
    return 'sin_usuario';
  end if;
  if hash <> crypt(p_actual || '-comandas', hash) then
    return 'pin_actual_incorrecto';
  end if;
  if p_nuevo !~ '^[0-9]{4}$' then
    return 'pin_nuevo_invalido';
  end if;
  update auth.users
     set encrypted_password = crypt(p_nuevo || '-comandas', gen_salt('bf')),
         updated_at = now()
   where id = uid;
  return 'ok';
end;
$$;

-- Descontar inventario: solo admin y mesero, y nunca cantidades negativas.
create or replace function public.deduct_ingredient(i_id uuid, i_qty numeric)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(private.staff_role(), '') not in ('admin', 'mesero') then
    raise exception 'No autorizado' using errcode = '42501';
  end if;
  if i_qty is null or i_qty < 0 then
    raise exception 'Cantidad invalida' using errcode = '22023';
  end if;
  update ingredients set stock = stock - i_qty where id = i_id;
end;
$$;

create or replace function public.deduct_stock(p_id uuid, p_qty numeric)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(private.staff_role(), '') not in ('admin', 'mesero') then
    raise exception 'No autorizado' using errcode = '42501';
  end if;
  if p_qty is null or p_qty < 0 then
    raise exception 'Cantidad invalida' using errcode = '22023';
  end if;
  update products
    set stock = stock - p_qty,
        available = case when track_stock and (stock - p_qty) <= 0 then false else available end
  where id = p_id and track_stock = true;
end;
$$;

-- Permisos de ejecucion: nada para visitantes sin sesion.
revoke execute on function public.my_profile() from public, anon;
revoke execute on function public.save_user(uuid, text, text, text, boolean) from public, anon;
revoke execute on function public.cambiar_pin(text, text) from public, anon;
revoke execute on function public.deduct_ingredient(uuid, numeric) from public, anon;
revoke execute on function public.deduct_stock(uuid, numeric) from public, anon;
grant execute on function public.my_profile() to authenticated;
grant execute on function public.save_user(uuid, text, text, text, boolean) to authenticated;
grant execute on function public.cambiar_pin(text, text) to authenticated;
grant execute on function public.deduct_ingredient(uuid, numeric) to authenticated;
grant execute on function public.deduct_stock(uuid, numeric) to authenticated;

-- ---------------------------------------------------------------
-- 3) Visitantes sin sesion: solo pueden listar el personal en la pantalla de login
-- ---------------------------------------------------------------
revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;
alter default privileges for role postgres in schema public revoke all on tables from anon;
alter default privileges for role postgres in schema public revoke all on sequences from anon;
alter default privileges for role postgres in schema public revoke all on functions from anon;

create or replace view public.public_staff as
  select id, name, email, role
  from public.app_users
  where active and coalesce(email, '') <> '';

revoke all on public.public_staff from public, anon, authenticated;
grant select on public.public_staff to anon, authenticated;

grant usage, select on sequence public.ticket_number_seq to authenticated;

-- ---------------------------------------------------------------
-- 4) Reglas por rol (RLS). Se borran las reglas anteriores y se crean de nuevo.
-- ---------------------------------------------------------------
do $$
declare p record;
begin
  for p in select schemaname, tablename, policyname from pg_policies where schemaname = 'public'
  loop
    execute format('drop policy %I on %I.%I', p.policyname, p.schemaname, p.tablename);
  end loop;
end $$;

-- app_users: el admin gestiona todo; los demas solo ven su propia fila.
create policy app_users_select on public.app_users for select to authenticated
  using ((select private.is_admin()) or lower(email) = lower(coalesce(auth.jwt() ->> 'email', '')));
create policy app_users_insert on public.app_users for insert to authenticated
  with check ((select private.is_admin()));
create policy app_users_update on public.app_users for update to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));
create policy app_users_delete on public.app_users for delete to authenticated
  using ((select private.is_admin()));

-- Comandas y configuracion: las ven admin, mesero y cocina.
create policy tickets_select on public.tickets for select to authenticated
  using ((select private.staff_role()) in ('admin', 'mesero', 'cocina'));
create policy app_config_select on public.app_config for select to authenticated
  using ((select private.staff_role()) in ('admin', 'mesero', 'cocina'));

-- Datos de atencion de mesas: los ven admin y mesero (cocina no).
create policy account_items_select on public.account_items for select to authenticated
  using ((select private.staff_role()) in ('admin', 'mesero'));
create policy categories_select on public.categories for select to authenticated
  using ((select private.staff_role()) in ('admin', 'mesero'));
create policy dining_tables_select on public.dining_tables for select to authenticated
  using ((select private.staff_role()) in ('admin', 'mesero'));
create policy ingredients_select on public.ingredients for select to authenticated
  using ((select private.staff_role()) in ('admin', 'mesero'));
create policy products_select on public.products for select to authenticated
  using ((select private.staff_role()) in ('admin', 'mesero'));
create policy takeaways_select on public.takeaways for select to authenticated
  using ((select private.staff_role()) in ('admin', 'mesero'));

-- Mesero y admin atienden mesas.
create policy account_items_insert on public.account_items for insert to authenticated
  with check ((select private.staff_role()) in ('admin', 'mesero'));
create policy account_items_update on public.account_items for update to authenticated
  using ((select private.staff_role()) in ('admin', 'mesero'))
  with check ((select private.staff_role()) in ('admin', 'mesero'));
create policy account_items_delete on public.account_items for delete to authenticated
  using ((select private.staff_role()) in ('admin', 'mesero'));

create policy takeaways_insert on public.takeaways for insert to authenticated
  with check ((select private.staff_role()) in ('admin', 'mesero'));
create policy takeaways_update on public.takeaways for update to authenticated
  using ((select private.staff_role()) in ('admin', 'mesero'))
  with check ((select private.staff_role()) in ('admin', 'mesero'));
create policy takeaways_delete on public.takeaways for delete to authenticated
  using ((select private.staff_role()) in ('admin', 'mesero'));

create policy dining_tables_update on public.dining_tables for update to authenticated
  using ((select private.staff_role()) in ('admin', 'mesero'))
  with check ((select private.staff_role()) in ('admin', 'mesero'));
create policy dining_tables_insert on public.dining_tables for insert to authenticated
  with check ((select private.is_admin()));
create policy dining_tables_delete on public.dining_tables for delete to authenticated
  using ((select private.is_admin()));

-- Comandas: mesero y admin las crean; cocina solo cambia su estado.
create policy tickets_insert on public.tickets for insert to authenticated
  with check ((select private.staff_role()) in ('admin', 'mesero'));
create policy tickets_update on public.tickets for update to authenticated
  using ((select private.staff_role()) in ('admin', 'mesero', 'cocina'))
  with check ((select private.staff_role()) in ('admin', 'mesero', 'cocina'));
create policy tickets_delete on public.tickets for delete to authenticated
  using ((select private.is_admin()));

-- Cobro: el mesero registra la venta, pero solo el admin puede consultarla.
create policy sales_insert on public.sales for insert to authenticated
  with check ((select private.staff_role()) in ('admin', 'mesero'));
create policy sales_select on public.sales for select to authenticated
  using ((select private.is_admin()));
create policy sales_update on public.sales for update to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));
create policy sales_delete on public.sales for delete to authenticated
  using ((select private.is_admin()));

-- Solo admin: menu, inventario, configuracion, caja, anulaciones, empleados y gastos.
create policy products_write on public.products for all to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));
create policy categories_write on public.categories for all to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));
create policy ingredients_write on public.ingredients for all to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));
create policy app_config_write on public.app_config for all to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));
create policy cancellations_admin on public.cancellations for all to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));
create policy cash_closes_admin on public.cash_closes for all to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));
create policy employees_admin on public.employees for all to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));
create policy gastos_admin on public.gastos for all to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));
