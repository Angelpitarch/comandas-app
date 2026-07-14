import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/enums.dart';
import '../../domain/models/ticket.dart';
import '../demo_data.dart';

class TicketsNotifier extends StateNotifier<List<Ticket>> {
  TicketsNotifier() : super(DemoData.tickets()) {
    _next = state.isEmpty
        ? 1
        : state.map((t) => t.number).reduce((a, b) => a > b ? a : b) + 1;
  }

  late int _next;

  int get nextNumber => _next;

  /// Agrega una comanda ya construida (enviada desde el pedido).
  void add(Ticket ticket) {
    state = [ticket, ...state];
    if (ticket.number >= _next) _next = ticket.number + 1;
  }

  int reserveNumber() => _next;

  void setStatus(String ticketId, TicketStatus status) {
    state = [
      for (final t in state)
        if (t.id == ticketId) t.copyWith(status: status) else t,
    ];
  }

  void registerPrint(String ticketId, PrintRecord record) {
    state = [
      for (final t in state)
        if (t.id == ticketId)
          t.copyWith(prints: [...t.prints, record])
        else
          t,
    ];
  }
}

final ticketsProvider =
    StateNotifierProvider<TicketsNotifier, List<Ticket>>(
        (ref) => TicketsNotifier());

/// Comandas activas (no entregadas ni anuladas) para el tablero de cocina.
final activeTicketsProvider = Provider<List<Ticket>>((ref) {
  final all = ref.watch(ticketsProvider);
  return all
      .where((t) =>
          t.status != TicketStatus.entregada &&
          t.status != TicketStatus.anulada)
      .toList();
});
