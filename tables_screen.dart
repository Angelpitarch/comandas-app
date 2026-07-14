import '../enums.dart';

/// Valor monetario con su moneda de origen.
/// El monto se guarda tal cual fue definido (en USD o en Bs). La conversion a
/// la otra moneda se hace al vuelo usando la tasa configurada, nunca se guarda
/// "ya convertido". Asi el historico es fiel aunque la tasa cambie.
class Money {
  final Currency currency;
  final double amount;

  const Money(this.amount, this.currency);

  const Money.usd(this.amount) : currency = Currency.usd;
  const Money.ves(this.amount) : currency = Currency.ves;

  /// Convierte este monto a USD usando la tasa (Bs por 1 USD).
  double toUsd(double vesPerUsd) =>
      currency == Currency.usd ? amount : amount / vesPerUsd;

  /// Convierte este monto a Bs usando la tasa (Bs por 1 USD).
  double toVes(double vesPerUsd) =>
      currency == Currency.ves ? amount : amount * vesPerUsd;

  /// Devuelve una copia con otro monto, conservando la moneda.
  Money copyAmount(double newAmount) => Money(newAmount, currency);
}
