-- 0006: avisos push a cocina/admin cuando entra una comanda nueva.
-- Guarda el "token" de cada celular que debe recibir avisos. Es segura de repetir.
-- (El disparador que envia el aviso y su clave secreta NO van en el repositorio.)

create table if not exists public.device_tokens (
  token text primary key,
  user_email text not null,
  role text not null,
  updated_at timestamptz not null default now()
);
alter table public.device_tokens enable row level security;
revoke all on public.device_tokens from anon, authenticated;
-- Sin reglas RLS: nadie lee ni escribe la tabla directamente; solo las funciones de abajo
-- y la funcion de envio (con llave de servicio).

create or replace function public.register_device(p_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare r text := private.staff_role();
begin
  if r not in ('admin', 'cocina') then
    raise exception 'No autorizado' using errcode = '42501';
  end if;
  if p_token is null or length(p_token) < 20 then
    raise exception 'Token invalido' using errcode = '22023';
  end if;
  insert into public.device_tokens (token, user_email, role, updated_at)
  values (p_token, lower(coalesce(auth.jwt() ->> 'email', '')), r, now())
  on conflict (token) do update
    set user_email = excluded.user_email, role = excluded.role, updated_at = now();
end;
$$;

create or replace function public.unregister_device(p_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(private.staff_role(), '') = '' then
    raise exception 'No autorizado' using errcode = '42501';
  end if;
  delete from public.device_tokens where token = p_token;
end;
$$;

revoke execute on function public.register_device(text) from public, anon;
revoke execute on function public.unregister_device(text) from public, anon;
grant execute on function public.register_device(text) to authenticated;
grant execute on function public.unregister_device(text) to authenticated;
