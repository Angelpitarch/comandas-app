-- 0004: la cocina solo puede cambiar el ESTADO de una comanda.
-- Antes, cocina podia modificar cualquier campo de un ticket (platos, notas, mesa...).
-- Ahora, si quien edita es "cocina", solo se permite cambiar:
--   * status   -> 'preparando', 'lista' o 'entregada' (nunca 'anulada', nunca volver a 'nueva')
--   * reprinted -> para marcar reimpresion
-- Admin y mesero no se ven afectados. Es segura de ejecutar varias veces.

create or replace function private.tickets_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if private.staff_role() = 'cocina' then
    -- cualquier columna distinta de status/reprinted debe quedar igual
    if (to_jsonb(new) - 'status' - 'reprinted') is distinct from (to_jsonb(old) - 'status' - 'reprinted') then
      raise exception 'Cocina solo puede cambiar el estado de la comanda' using errcode = '42501';
    end if;
    if new.status is distinct from old.status then
      if old.status in ('anulada', 'entregada') then
        raise exception 'Esta comanda ya esta cerrada' using errcode = '42501';
      end if;
      if new.status not in ('preparando', 'lista', 'entregada') then
        raise exception 'Estado no permitido para cocina' using errcode = '42501';
      end if;
    end if;
  end if;
  return new;
end;
$$;

revoke all on function private.tickets_guard() from public, anon;

drop trigger if exists tickets_guard on public.tickets;
create trigger tickets_guard
  before update on public.tickets
  for each row execute function private.tickets_guard();
