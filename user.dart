import 'package:flutter/material.dart';

/// Tema visual de la app. Colores calidos acordes a un puesto de comida.
class AppTheme {
  static const Color primary = Color(0xFFD84315); // naranja/rojo apetitoso
  static const Color secondary = Color(0xFF2E7D32);
  static const Color surface = Color(0xFFFFF8F3);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: secondary,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 1.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: const ChipThemeData(
        side: BorderSide(color: Color(0x22000000)),
      ),
    );
  }

  /// Colores por estado de mesa.
  static Color tableColor(String statusName) {
    switch (statusName) {
      case 'disponible':
        return const Color(0xFF66BB6A);
      case 'ocupada':
        return const Color(0xFFFFA726);
      case 'pedidoEnviado':
        return const Color(0xFF42A5F5);
      case 'pedidoListo':
        return const Color(0xFF26C6DA);
      case 'solicitandoCuenta':
        return const Color(0xFFAB47BC);
      case 'pendientePago':
        return const Color(0xFFEF5350);
      default:
        return const Color(0xFF90A4AE);
    }
  }
}
