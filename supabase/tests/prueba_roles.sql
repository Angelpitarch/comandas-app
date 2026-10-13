-- PRUEBA DE ROLES (no cambia nada en tu base de datos).
-- Como usarla: Supabase -> SQL Editor -> pegar todo -> Run.
-- Al final SIEMPRE muestra un "error" que empieza con PRUEBA_TERMINADA: es a proposito,
-- asi todo se deshace solo. El resultado de la prueba va dentro de ese mensaje.
--
-- Que debes ver (OK = permitido, ERR = bloqueado, numero = filas que pudo leer o modificar;
-- 0 puede significar "no ve nada" o "tabla vacia"):
--
--  ADMIN : puede leer y escribir todo. save_user=OK, save_user_rol_malo=ERR, my_profile=admin.
--  MESERO: lee tickets, config, productos, inventario, mesas, cuentas, para llevar y categorias.
--          NO lee sales, cash_closes, cancellations, employees ni gastos (0).
--          escribe: tickets, mesas, cuentas y ventas = OK; inventario, productos y config = 0;
--          gastos y anulaciones = ERR; save_user = ERR; deduct = OK; my_profile=mesero.
--  COCINA: solo lee tickets y config. tickets.update > 0, todo lo demas = ERR o 0.
--          deduct = ERR; save_user = ERR; my_profile=cocina.
--          Comanda de prueba: cocina_estado=1 (puede cambiar estado), cocina_cambia_nota=ERR,
--          cocina_anula=ERR. En admin y mesero esos tres = 1, 1, 1 (no hay restriccion).
--  ANON  : solo public_staff se puede leer; todo lo demas = ERR.

do $t$
declare
  r text := E'\n'; n int; rl text; em text; tb text; sid uuid; iid uuid;
begin
  foreach rl in array array['admin','mesero','cocina'] loop
    select email into em from public.app_users where role = rl and active limit 1;
    if em is null then
      r := r || upper(rl) || E': (no hay usuario activo con este rol)\n';
      continue;
    end if;
    begin
      -- comanda de prueba (se deshace al final del rol)
      insert into public.tickets (table_number, status, note) values (999, 'nueva', 'prueba');
      perform set_config('request.jwt.claims', json_build_object('email', em, 'role', 'authenticated')::text, true);
      set local role authenticated;
      r := r || upper(rl) || E'\n  lee: ';
      foreach tb in array array['tickets','app_config','products','ingredients','dining_tables','account_items','takeaways','categories','sales','cash_closes','cancellations','employees','gastos','app_users'] loop
        execute format('select count(*) from public.%I', tb) into n;
        r := r || tb || '=' || n || ' ';
      end loop;
      r := r || E'\n  escribe: ';
      begin update public.tickets set status = status; get diagnostics n = row_count; r := r || 'tickets.update=' || n || ' '; exception when others then r := r || 'tickets.update=ERR '; end;
      begin update public.tickets set status = 'preparando' where table_number = 999; get diagnostics n = row_count; r := r || 'cocina_estado=' || n || ' '; exception when others then r := r || 'cocina_estado=ERR '; end;
      begin update public.tickets set note = 'hack' where table_number = 999; get diagnostics n = row_count; r := r || 'cocina_cambia_nota=' || n || ' '; exception when others then r := r || 'cocina_cambia_nota=ERR '; end;
      begin update public.tickets set status = 'anulada' where table_number = 999; get diagnostics n = row_count; r := r || 'cocina_anula=' || n || ' '; exception when others then r := r || 'cocina_anula=ERR '; end;
      begin insert into public.tickets (table_number) values (1); r := r || 'tickets.insert=OK '; exception when others then r := r || 'tickets.insert=ERR '; end;
      begin update public.dining_tables set status = status; get diagnostics n = row_count; r := r || 'mesas.update=' || n || ' '; exception when others then r := r || 'mesas.update=ERR '; end;
      begin insert into public.account_items (product_name) values ('t'); r := r || 'cuenta.insert=OK '; exception when others then r := r || 'cuenta.insert=ERR '; end;
      begin insert into public.sales default values; r := r || 'ventas.insert=OK '; exception when others then r := r || 'ventas.insert=ERR '; end;
      begin update public.ingredients set name = name; get diagnostics n = row_count; r := r || 'inventario.update=' || n || ' '; exception when others then r := r || 'inventario.update=ERR '; end;
      begin update public.products set name = name; get diagnostics n = row_count; r := r || 'productos.update=' || n || ' '; exception when others then r := r || 'productos.update=ERR '; end;
      begin update public.app_config set rate = rate; get diagnostics n = row_count; r := r || 'config.update=' || n || ' '; exception when others then r := r || 'config.update=ERR '; end;
      begin update public.app_users set role = role; get diagnostics n = row_count; r := r || 'usuarios.update=' || n || ' '; exception when others then r := r || 'usuarios.update=ERR '; end;
      begin insert into public.gastos (concept) values ('t'); r := r || 'gastos.insert=OK '; exception when others then r := r || 'gastos.insert=ERR '; end;
      begin insert into public.cancellations default values; r := r || 'anulacion.insert=OK '; exception when others then r := r || 'anulacion.insert=ERR '; end;
      select id into iid from public.ingredients limit 1;
      begin perform public.deduct_ingredient(coalesce(iid, gen_random_uuid()), 0); r := r || 'deduct=OK '; exception when others then r := r || 'deduct=ERR '; end;
      begin perform public.deduct_ingredient(gen_random_uuid(), -5); r := r || 'deduct_negativo=OK(MAL) '; exception when others then r := r || 'deduct_negativo=ERR '; end;
      select id into sid from public.app_users where role = 'cocina' limit 1;
      begin perform public.save_user(sid, 'x', '', 'cocina', true); r := r || 'save_user=OK '; exception when others then r := r || 'save_user=ERR '; end;
      begin perform public.save_user(sid, 'x', '', 'superjefe', true); r := r || 'save_user_rol_malo=OK(MAL) '; exception when others then r := r || 'save_user_rol_malo=ERR '; end;
      begin select role into tb from public.my_profile(); r := r || 'my_profile=' || coalesce(tb, 'NULL') || ' '; exception when others then r := r || 'my_profile=ERR '; end;
      r := r || E'\n';
      raise exception 'fin_rol';  -- deshace lo que hizo este rol
    exception when others then
      if sqlerrm <> 'fin_rol' then r := r || E'  ERROR INESPERADO: ' || sqlerrm || E'\n'; end if;
    end;
  end loop;

  begin
    r := r || E'ANON\n  ';
    perform set_config('request.jwt.claims', '{"role":"anon"}', true);
    set local role anon;
    begin select count(*) into n from public.public_staff; r := r || 'public_staff=' || n || ' '; exception when others then r := r || 'public_staff=ERR '; end;
    begin insert into public.public_staff (name) values ('x'); r := r || 'public_staff.insert=OK(MAL) '; exception when others then r := r || 'public_staff.insert=ERR '; end;
    begin select count(*) into n from public.app_users; r := r || 'app_users=' || n || '(MAL) '; exception when others then r := r || 'app_users=ERR '; end;
    begin select count(*) into n from public.sales; r := r || 'sales=' || n || '(MAL) '; exception when others then r := r || 'sales=ERR '; end;
    begin perform public.save_user(null, 'x', '1234', 'admin', true); r := r || 'save_user=OK(MAL) '; exception when others then r := r || 'save_user=ERR '; end;
    begin perform public.my_profile(); r := r || 'my_profile=OK(MAL) '; exception when others then r := r || 'my_profile=ERR '; end;
    begin perform public.deduct_ingredient(gen_random_uuid(), 1); r := r || 'deduct=OK(MAL) '; exception when others then r := r || 'deduct=ERR '; end;
    raise exception 'fin_rol';
  exception when others then
    if sqlerrm <> 'fin_rol' then r := r || E'  ERROR INESPERADO: ' || sqlerrm || E'\n'; end if;
  end;

  raise exception E'PRUEBA_TERMINADA (no se guardo nada): %', r;
end $t$;
