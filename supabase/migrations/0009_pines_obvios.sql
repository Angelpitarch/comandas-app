-- Rechaza PIN obvios (123456, 000000, 121212, 123321, etc.) al crear o cambiar un PIN.
-- Los PIN que ya existen siguen funcionando: la regla solo aplica a PIN nuevos.

create or replace function private.pin_debil(p text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select
    -- un solo numero repetido: 000000, 111111, ...
    p ~ '^(\d)\1{5}$'
    -- dos numeros repetidos (121212) o bloque de tres repetido (123123)
    or p ~ '^(\d\d)\1\1$'
    or p ~ '^(\d\d\d)\1$'
    -- capicua: 123321, 100001
    or p ~ '^(\d)(\d)(\d)\3\2\1$'
    -- parejas seguidas: 112233, 223344, ...
    or p ~ '^(\d)\1(\d)\2(\d)\3$'
    -- escaleras ascendentes y descendentes (con vuelta al 0)
    or p in ('012345','123456','234567','345678','456789','567890','678901','789012','890123','901234',
             '987654','876543','765432','654321','543210','432109','321098','210987','109876','098765');
$$;
revoke all on function private.pin_debil(text) from public, anon;
grant execute on function private.pin_debil(text) to authenticated;

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
  if p_nuevo !~ '^[0-9]{6}$' then
    return 'pin_nuevo_invalido';
  end if;
  if private.pin_debil(p_nuevo) then
    return 'pin_nuevo_facil';
  end if;
  update auth.users
     set encrypted_password = crypt(p_nuevo || '-comandas', gen_salt('bf')),
         updated_at = now()
   where id = uid;
  return 'ok';
end;
$$;

create or replace function public.save_user(p_id uuid, p_name text, p_pin text, p_role text, p_active boolean)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_email text;
begin
  if not private.is_admin() then
    raise exception 'No autorizado' using errcode = '42501';
  end if;
  if p_role not in ('admin', 'cocina', 'mesero') then
    raise exception 'Rol invalido' using errcode = '22023';
  end if;
  if (p_id is null or coalesce(p_pin, '') <> '') and coalesce(p_pin, '') !~ '^[0-9]{6}$' then
    raise exception 'El PIN debe ser de 6 numeros' using errcode = '22023';
  end if;
  if coalesce(p_pin, '') <> '' and private.pin_debil(p_pin) then
    raise exception 'PIN demasiado facil de adivinar' using errcode = '22023';
  end if;
  if p_id is null then
    insert into app_users(name, pin, pin_hash, role, active)
      values (p_name, '', crypt(p_pin, gen_salt('bf')), p_role, p_active);
  else
    update app_users set name = p_name, role = p_role, active = p_active,
      pin_hash = case when coalesce(p_pin,'') <> '' then crypt(p_pin, gen_salt('bf')) else pin_hash end
    where id = p_id
    returning email into v_email;
    if coalesce(p_pin, '') <> '' and coalesce(v_email, '') <> '' then
      update auth.users
         set encrypted_password = crypt(p_pin || '-comandas', gen_salt('bf')),
             updated_at = now()
       where lower(email) = lower(v_email);
    end if;
  end if;
end;
$$;

revoke execute on function public.cambiar_pin(text, text) from public, anon;
revoke execute on function public.save_user(uuid, text, text, text, boolean) from public, anon;
grant execute on function public.cambiar_pin(text, text) to authenticated;
grant execute on function public.save_user(uuid, text, text, text, boolean) to authenticated;
