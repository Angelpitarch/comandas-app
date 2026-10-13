# Comandas – Puesto de comida

App Flutter para administrar un puesto de comida: mesas, pedidos, cocina, cobro en USD y Bs,
inventario con recetas, caja, empleados y gastos. Los datos viven en **Supabase** y se comparten
en tiempo real entre dispositivos.

## Roles

| Rol | Qué ve y qué puede hacer |
|---|---|
| **Mesero** | Solo atiende mesas y pedidos para llevar: toma pedidos, los envía a cocina, cobra y libera la mesa. No ve ventas, caja, gastos ni empleados. |
| **Cocina** | Solo ve las comandas y cambia su estado (nueva → preparando → lista). No puede anular ni modificar el contenido de una comanda (lo impide un disparador en la base de datos). |
| **Administrador** | Todo: usuarios y roles, menú, inventario, categorías, tasa, caja, anulaciones, empleados, gastos (se descuentan en Rentabilidad, cierre de caja y reportes), reportes por semana y mes e historial. También puede abrir las pantallas de Mesero y de Cocina. |

Esto se aplica **en la base de datos** (reglas RLS en `supabase/migrations/0002_seguridad_por_rol.sql`),
no solo en la pantalla: aunque alguien modifique la app, el servidor rechaza lo que su rol no permite.

## Poner en marcha la base de datos (una sola vez)

1. En Supabase abre **SQL Editor** y ejecuta, en orden, los archivos de `supabase/migrations/`:
   `0001_schema.sql`, `0002_seguridad_por_rol.sql`, `0003_datos_iniciales.sql`, `0004_cocina_solo_estado.sql` `0005_cierre_con_gastos.sql`, `0006_avisos_push.sql` y `0007_disparador_avisos.sql`.
   Son seguros de repetir: no borran datos.
2. Crea el primer administrador:
   - En **Authentication → Users → Add user** crea un usuario con su correo y la contraseña
     `<PIN de 4 dígitos>-comandas` (por ejemplo `1234-comandas`). Marca "Auto confirm".
   - En **SQL Editor** ejecuta (con tus datos):
     ```sql
     insert into public.app_users (name, pin, role, active, email)
     values ('Tu nombre', '', 'admin', true, 'tu-correo@ejemplo.com');
     ```
   El correo debe ser **exactamente el mismo** en Authentication y en `app_users`.
3. Entra a la app con ese administrador y crea los demás usuarios desde **Usuarios**.
4. Ejecuta `supabase/tests/prueba_roles.sql` para comprobar los permisos de cada rol
   (no guarda nada; el resultado aparece dentro de un mensaje que empieza con `PRUEBA_TERMINADA`).

## Recomendaciones de seguridad (hazlas en el panel de Supabase)

- **Authentication → Sign In / Providers**: desactiva "Allow new users to sign up".
  Así nadie puede crearse una cuenta por su cuenta.
- **Authentication → Rate limits**: deja activos los límites de inicio de sesión.
- **Authentication → Password security**: activa "Leaked password protection" si tu plan lo permite.
- La pantalla de acceso lista el personal (nombre y correo) sin sesión. Con PIN de 4 dígitos, quien
  conozca un correo puede intentar adivinar el PIN. Usa PIN poco obvios, cámbialos si sospechas algo
  y mantén los límites de inicio de sesión activos.
- Nunca subas al repositorio llaves `service_role`, contraseñas ni archivos `.env`.
  La llave `sb_publishable_...` que está en `lib/main.dart` sí es pública por diseño.

## Avisos con la app cerrada (Firebase)

Cocina y administrador reciben un aviso en el celular cuando entra una comanda nueva, aunque la app
este cerrada. Piezas: la app (registra el celular al iniciar sesion), la tabla `device_tokens`
(`0006_avisos_push.sql`), la funcion `supabase/functions/notify-comanda` y un disparador en la base de
datos que la llama. Secretos en Supabase (nunca en el repositorio): `WEBHOOK_SECRET` y
`FCM_SERVICE_ACCOUNT` (JSON de la cuenta de servicio de Firebase). Los datos de `kFirebaseOptions`
en `lib/main.dart` son publicos por diseno.

## Compilar el APK

Desde GitHub → **Actions → Build APK → Run workflow**:
- `release`: primera vez o cambios grandes (genera el APK para instalar).
- `patch`: actualización por el aire (Shorebird), para cambios solo de código Dart.

**Actualizaciones por el aire (patch) sin romperse:** un `patch` solo funciona si las librerías son
exactamente las mismas que las del `release` instalado. Por eso `pubspec.lock` está en el repositorio
y el flujo lo guarda solo después de cada `release`. Regla práctica: si cambias `pubspec.yaml`
(agregar o actualizar librerías) haz un `release` nuevo con un `version:` más alto; si solo cambias
código Dart, haz `patch`.

Secretos necesarios en GitHub (Settings → Secrets): `SHOREBIRD_TOKEN` y, para el respaldo diario,
`SUPABASE_DB_URL`.

## Estructura

```
lib/main.dart                         Toda la app (un solo archivo)
supabase/migrations/                  Esquema, seguridad por rol, datos iniciales candado de cocina y gastos en el cierre
supabase/tests/prueba_roles.sql       Prueba de permisos por rol
.github/workflows/build-apk.yml       Compilación del APK y parches Shorebird
.github/workflows/backup.yml          Respaldo diario de la base de datos
```
