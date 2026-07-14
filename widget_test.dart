import '../enums.dart';
import 'order_item.dart';

/// Pedido = cuenta acumulada de una mesa (o pedido para llevar).
/// Una mesa tiene un solo pedido abierto que acumula varias comandas.
class Order {
  final String id;
  final int? tableNumber; // null = para llevar
  final ServiceType serviceType;
  final String waiterId;
  final String waiterName;
  final int guests;
  final DateTime openedAt;
  final List<OrderItem> items; // items del carrito aun no enviados
  final String? generalNote;
  final bool closed;

  const Order({
    required this.id,
    required this.serviceType,
    required this.waiterId,
    required this.waiterName,
    required this.openedAt,
    this.tableNumber,
    this.guests = 1,
    this.items = const [],
    this.generalNote,
    this.closed = false,
  });

  double totalToUsd(double rate) =>
      items.fold(0.0, (sum, it) => sum + it.lineToUsd(rate));

  int get itemCount => items.fold(0, (sum, it) => sum + it.quantity);

  Order copyWith({
    List<OrderItem>? items,
    String? generalNote,
    bool clearGeneralNote = false,
    int? guests,
    bool? closed,
  }) {
    return Order(
      id: id,
      tableNumber: tableNumber,
      serviceType: serviceType,
      waiterId: waiterId,
      waiterName: waiterName,
      openedAt: openedAt,
      guests: guests ?? this.guests,
      items: items ?? this.items,
      generalNote: clearGeneralNote ? null : (generalNote ?? this.generalNote),
      closed: closed ?? this.closed,
    );
  }
}
