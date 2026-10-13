-- 0003: datos iniciales para una base nueva. No pisa nada si ya existen.

insert into public.app_config (id, rate, business_name)
values (1, 36.5, 'Puesto de Comida')
on conflict (id) do nothing;

insert into public.categories (key, label, emoji, "position", protected) values
  ('hamburguesas', 'Hamburguesas',     '🍔', 10, true),
  ('perros',       'Perros calientes', '🌭', 20, true),
  ('papas',        'Raciones',         '🍱', 30, true),
  ('bebidas',      'Bebidas',          '🥤', 40, true),
  ('combos',       'Pollo Frito',      '🍗', 50, true),
  ('otros',        'Salchipapas',      '🍟', 60, true)
on conflict (key) do nothing;

insert into public.dining_tables (number)
select n from generate_series(1, 9) as n
on conflict (number) do nothing;
