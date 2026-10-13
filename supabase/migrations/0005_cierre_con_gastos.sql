-- 0005: el cierre de caja guarda tambien el total de gastos del turno.
-- Es segura de ejecutar varias veces y no borra nada. Ejecutala ANTES de instalar la app 0.6.2.
alter table public.cash_closes
  add column if not exists gastos_usd numeric not null default 0;
