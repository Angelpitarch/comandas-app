import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/enums.dart';
import '../../domain/models/order.dart';
import '../../domain/models/order_item.dart';
import '../../domain/models/restaurant_table.dart';
import '../../domain/models/ticket.dart';
import 'kitchen_providers.dart';
import 'tables_providers.dart';

/// Gestiona los pedidos abiertos (borradores del carrito antes de enviar) y
/// coordina el envio a cocina, la creacion de comandas y el estado de la mesa.
class OrdersNotifier extends StateNotifier<List<Order>> {
  final Ref _ref;
  int _seq = 0;

  OrdersNotifier(this._ref) : super([]);

  Order? byId(String id) {
    for (final o in state) {
      if (o.id == id) return o;
    }
    return null;
  }

  Order? _openForTable(int number) {
    for (final o in state) {
      if (o.tableNumber == number && !o.closed) return o;
    }
    return null;
  }

  /// Devuelve el pedido abierto de la mesa o crea uno nuevo.
  Order openForTable(RestaurantTable table, String waiterName) {
    final existing = _openForTable(table.number);
    if (existing != null) return existing;
    final order = Order(
      id: 'o${++_seq}',
      serviceType: ServiceType.mesa,
      waiterId: '',
      waiterName: waiterName,
      openedAt: DateTime.now(),
      tableNumber: table.number,
      guests: table.guests == 0 ? 1 : table.guests,
    );
    state = [...state, order];
    return order;
  }

  Order createTakeaway(String waiterName) {
    final order = Order(
      id: 'o${++_seq}',
      serviceType: ServiceType.paraLlevar,
      waiterId: '',
      waiterName: waiterName,
      openedAt: DateTime.now(),
    );
    state = [...state, order];
    return order;
  }

  void _replace(Order updated) {
    state = [for (final o in state) o.id == updated.id ? updated : o];
  }

  void addItem(String orderId, OrderItem item) {
    final o = byId(orderId);
    if (o == null) return;
    _replace(o.copyWith(items: [...o.items, item]));
  }

  void updateItem(String orderId, OrderItem item) {
    final o = byId(orderId);
    if (o == null) return;
    _replace(o.copyWith(
      items: [for (final it in o.items) it.id == item.id ? item : it],
    ));
  }

  void removeItem(String orderId, String itemId) {
    final o = byId(orderId);
    if (o == null) return;
    _replace(o.copyWith(
        items: o.items.where((it) => it.id != itemId).toList()));
  }

  void setGeneralNote(String orderId, String? note) {
    final o = byId(orderId);
    if (o == null) return;
    _replace(o.copyWith(
        generalNote: note, clearGeneralNote: note == null));
  }

  bool _tableHasTickets(int? tableNumber) {
    if (tableNumber == null) return false;
    for (final t in _ref.read(ticketsProvider)) {
      if (t.tableNumber == tableNumber && t.status != TicketStatus.anulada) {
        return true;
      }
    }
    return false;
  }

  /// Convierte los items del carrito en una comanda inmutable y la envia a
  /// cocina. Si la mesa ya tenia comandas, la nueva se marca como ADICION.
  /// Devuelve la comanda creada, o null si no hay items.
  Ticket? sendToKitchen(String orderId, {required String byUser}) {
    final order = byId(orderId);
    if (order == null || order.items.isEmpty) return null;

    final tickets = _ref.read(ticketsProvider.notifier);
    final isAddition = _tableHasTickets(order.tableNumber);

    final lines = <TicketLine>[
      for (final it in order.items)
        TicketLine(
          productName: it.product.name,
          quantity: it.quantity,
          sizeName: it.size?.name,
          extras: it.extras.map((e) => e.name).toList(),
          removedIngredients: it.removedIngredients,
          note: it.note,
        ),
    ];

    final ticket = Ticket(
      id: 'tk${DateTime.now().microsecondsSinceEpoch}',
      number: tickets.reserveNumber(),
      type: isAddition ? TicketType.adicion : TicketType.normal,
      serviceType: order.serviceType,
      tableNumber: order.tableNumber,
      waiterName: order.waiterName,
      sentAt: DateTime.now(),
      status: TicketStatus.nueva,
      lines: lines,
      generalNote: order.generalNote,
    );

    tickets.add(ticket);

    // La mesa pasa a "pedido enviado".
    if (order.tableNumber != null) {
      _ref.read(tablesProvider.notifier).setStatus(
            order.tableNumber!,
            TableStatus.pedidoEnviado,
          );
    }

    // Los items ya enviados se limpian del carrito; el pedido sigue abierto.
    _replace(order.copyWith(items: [], clearGeneralNote: true));
    return ticket;
  }
}

final ordersProvider =
    StateNotifierProvider<OrdersNotifier, List<Order>>(
        (ref) => OrdersNotifier(ref));
