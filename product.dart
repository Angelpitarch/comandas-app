import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Configuracion global de la app (Etapa 1: en memoria).
/// En etapas futuras vendra de la base de datos / nube.
class AppConfig {
  /// Tasa de cambio: cuantos Bolivares equivale 1 USD.
  final double vesPerUsd;

  /// Fecha/hora de la ultima actualizacion de la tasa.
  final DateTime rateUpdatedAt;

  /// Ancho de papel de la impresora (mm). Preparado para Etapa 4.
  final int paperWidthMm;

  /// Nombre del negocio (aparece en la comanda).
  final String businessName;

  const AppConfig({
    required this.vesPerUsd,
    required this.rateUpdatedAt,
    this.paperWidthMm = 80,
    this.businessName = 'Puesto de Comida',
  });

  AppConfig copyWith({
    double? vesPerUsd,
    DateTime? rateUpdatedAt,
    int? paperWidthMm,
    String? businessName,
  }) {
    return AppConfig(
      vesPerUsd: vesPerUsd ?? this.vesPerUsd,
      rateUpdatedAt: rateUpdatedAt ?? this.rateUpdatedAt,
      paperWidthMm: paperWidthMm ?? this.paperWidthMm,
      businessName: businessName ?? this.businessName,
    );
  }
}

class AppConfigNotifier extends StateNotifier<AppConfig> {
  AppConfigNotifier()
      : super(AppConfig(
          vesPerUsd: 36.50,
          rateUpdatedAt: DateTime.now(),
        ));

  void updateRate(double rate) {
    state = state.copyWith(vesPerUsd: rate, rateUpdatedAt: DateTime.now());
  }

  void setPaperWidth(int mm) => state = state.copyWith(paperWidthMm: mm);
}

final appConfigProvider =
    StateNotifierProvider<AppConfigNotifier, AppConfig>((ref) {
  return AppConfigNotifier();
});
