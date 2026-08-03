import 'package:flutter/material.dart';

/// Tema oscuro + naranja, elegante, para Comandas App.
/// Reemplaza tu app_theme.dart actual por este archivo.
class AppTheme {
  AppTheme._();

  // Paleta base — cámbiala aquí y se actualiza en toda la app.
  static const Color background = Color(0xFF17130F);
  static const Color surface = Color(0xFF221C17);
  static const Color surfaceBorder = Color(0xFF332A22);
  static const Color orange = Color(0xFFE8823C);
  static const Color orangeDark = Color(0xFFC4622A);
  static const Color textPrimary = Color(0xFFF5EFE8);
  static const Color textSecondary = Color(0xFF9C9187);
  static const Color textMuted = Color(0xFF6B6259);

  static ThemeData get theme {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: orange,
        onPrimary: background,
        secondary: orangeDark,
        onSecondary: textPrimary,
        surface: surface,
        onSurface: textPrimary,
        surfaceContainerHighest: surfaceBorder,
        error: Color(0xFFE5484D),
        onError: textPrimary,
        outline: surfaceBorder,
      ),
      textTheme: base.textTheme
          .apply(bodyColor: textPrimary, displayColor: textPrimary)
          .copyWith(
            titleLarge: const TextStyle(
                color: textPrimary, fontWeight: FontWeight.w500, fontSize: 19),
            titleMedium: const TextStyle(
                color: textPrimary, fontWeight: FontWeight.w500, fontSize: 16),
            bodyMedium: const TextStyle(color: textPrimary, fontSize: 14),
            bodySmall: const TextStyle(color: textSecondary, fontSize: 12),
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle:
            TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w500),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: surfaceBorder),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: orange,
        textColor: textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: orange,
          foregroundColor: background,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: orange,
          foregroundColor: background,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: orange,
        foregroundColor: background,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: orange, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textSecondary),
      ),
      dividerTheme: const DividerThemeData(color: surfaceBorder, thickness: 1),
      iconTheme: const IconThemeData(color: orange),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
