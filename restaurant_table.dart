import '../../domain/enums.dart';
import '../../domain/models/money.dart';

/// Utilidades de formato monetario con estilo venezolano:
/// separador de miles '.' y decimales ','.
class MoneyFormat {
  static String _group(String intPart) {
    final buf = StringBuffer();
    final n = intPart.length;
    for (var i = 0; i < n; i++) {
      if (i > 0 && (n - i) % 3 == 0) buf.write('.');
      buf.write(intPart[i]);
    }
    return buf.toString();
  }

  static String _fmt(double value, {int decimals = 2}) {
    final fixed = value.abs().toStringAsFixed(decimals);
    final parts = fixed.split('.');
    final intPart = _group(parts[0]);
    final sign = value < 0 ? '-' : '';
    if (decimals == 0) return '$sign$intPart';
    return '$sign$intPart,${parts[1]}';
  }

  static String usd(double amount) => '\$${_fmt(amount)}';

  static String ves(double amount) => 'Bs ${_fmt(amount)}';

  /// Muestra un monto en su moneda base y el equivalente en la otra.
  /// Ej: "\$3,00 · Bs 109,50"
  static String dual(Money price, double vesPerUsd) {
    final u = price.toUsd(vesPerUsd);
    final v = price.toVes(vesPerUsd);
    return '${usd(u)} · ${ves(v)}';
  }

  /// Dado un total ya calculado en USD, muestra ambos.
  static String dualFromUsd(double usdAmount, double vesPerUsd) {
    return '${usd(usdAmount)} · ${ves(usdAmount * vesPerUsd)}';
  }

  static String currencyBadge(Currency c) => c == Currency.usd ? 'USD' : 'Bs';
}
