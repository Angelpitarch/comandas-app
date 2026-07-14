name: Build APK

on:
  workflow_dispatch:
  push:
    branches: [ main, master ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Java 17
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable

      - name: Generar carpeta android
        run: flutter create --platforms=android --project-name comandas_app --org com.puestocomida .

      - name: Dependencias
        run: flutter pub get

      - name: Analizar
        run: flutter analyze || true

      - name: Compilar APK release
        run: flutter build apk --release

      - name: Publicar APK
        uses: actions/upload-artifact@v4
        with:
          name: comandas-apk
          path: build/app/outputs/flutter-apk/app-release.apk
          if-no-files-found: error
