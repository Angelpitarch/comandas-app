-- 0007: disparador que llama a la funcion notify-comanda cuando entra una comanda nueva.
-- Requiere la extension pg_net (se activa en 0006). La clave compartida la genera la propia
-- base de datos y vive en private.app_secrets: NO esta en el repositorio.
-- Para ver el valor y copiarlo al secreto WEBHOOK_SECRET de Supabase (Edge Functions > Secrets):
--   select value from private.app_secrets where name = 'webhook_notify';
-- Es segura de ejecutar varias veces.

create table if not exists private.app_secrets (
  name text primary key,
  value text not null
);
alter table private.app_secrets enable row level security;
revoke all on private.app_secrets from public, anon, authenticated;
insert into private.app_secrets (name, value)
values ('webhook_notify', replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''))
on conflict (name) do nothing;

create or replace function private.notify_new_ticket()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'nueva' then
    perform net.http_post(
      url := 'https://tmjejukvdcfifajnmlca.supabase.co/functions/v1/notify-comanda',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-webhook-secret', (select value from private.app_secrets where name = 'webhook_notify')),
      body := jsonb_build_object('number', new.number, 'table', new.table_number, 'takeaway', new.takeaway_name, 'adicion', new.adicion)
    );
  end if;
  return new;
exception when others then
  return new;  -- un fallo del aviso nunca debe impedir guardar la comanda
end;
$$;
revoke all on function private.notify_new_ticket() from public, anon, authenticated;

drop trigger if exists tickets_notify on public.tickets;
create trigger tickets_notify
  after insert on public.tickets
  for each row execute function private.notify_new_ticket();
