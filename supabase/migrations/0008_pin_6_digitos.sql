-- PIN de 6 digitos.
-- * cambiar_pin: el PIN nuevo debe tener 6 numeros.
-- * save_user: el PIN que escribe el admin debe tener 6 numeros y, al editar un usuario
--   que ya tiene login, tambien cambia su clave real de acceso (antes solo cambiaba pin_hash,
--   que la app no usa para entrar).
-- Los usuarios con PIN de 4 numeros siguen entrando; la app les exige cambiarlo al entrar.

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
