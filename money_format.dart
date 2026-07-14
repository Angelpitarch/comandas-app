# Comandas — Puesto de Comida (Etapa 1: prototipo)

App Flutter para administrar un puesto de comida rápida. Esta es la **Entrega 1**:
prototipo visual con datos de demostración en memoria. **Aún no** incluye base de
datos persistente, impresión Bluetooth ni sincronización en la nube (llegan en
entregas posteriores), pero la arquitectura ya está preparada para ellas.

## Qué incluye

- Inicio de sesión por **PIN** (Admin 1111 · Mesero 2222 · Cocina 3333).
- **Selector de perfil** (modo prueba: puedes entrar a los 3 perfiles).
- **Mesas** con estados y color.
- **Catálogo** de productos y bebidas por categoría.
- **Toma de pedido**: tamaños, extras, quitar ingredientes, observaciones, cantidades.
- **Doble moneda** USD + Bs. con tasa configurable (Configuración).
- **Enviar a cocina** (botón bloqueado mientras procesa; adiciones marcadas).
- **Tablero de cocina** con temporizador, estados y vista previa del ticket.

## Cómo generar el APK en la nube (GitHub Actions)

Este entorno no puede compilar el APK, así que se compila en GitHub Actions
(gratis) y el APK queda listo para descargar:

1. Crea un repositorio nuevo en GitHub (privado o público).
2. Sube el contenido de esta carpeta (incluida la carpeta `.github`).
3. Entra a la pestaña **Actions** del repo → workflow **Build APK** → **Run workflow**.
4. Al terminar (unos minutos), abre la ejecución y descarga el artefacto
   **comandas-apk** (contiene `app-release.apk`).
5. Copia el APK a tu teléfono Android e instálalo (activa "Instalar apps de
   orígenes desconocidos" si te lo pide).

El workflow genera automáticamente la carpeta `android/` con `flutter create`,
así que no necesitas configurarla a mano.

## Compilar localmente (alternativa)

Requiere Flutter instalado:

```
flutter create --platforms=android .
flutter pub get
flutter build apk --release
```

El APK queda en `build/app/outputs/flutter-apk/app-release.apk`.
