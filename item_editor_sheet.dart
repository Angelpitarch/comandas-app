import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/enums.dart';
import '../../domain/models/restaurant_table.dart';
import '../demo_data.dart';

class TablesNotifier extends StateNotifier<List<RestaurantTable>> {
  TablesNotifier() : super(DemoData.tables());

  RestaurantTable byNumber(int number) =>
      state.firstWhere((t) => t.number == number);

  void open(int number, String waiterName, int guests) {
    state = [
      for (final t in state)
        if (t.number == number)
          t.copyWith(
            status: TableStatus.ocupada,
            waiterName: waiterName,
            guests: guests,
            openedAt: t.openedAt ?? DateTime.now(),
          )
        else
          t,
    ];
  }

  void setStatus(int number, TableStatus status) {
    state = [
      for (final t in state)
        if (t.number == number) t.copyWith(status: status) else t,
    ];
  }

  void addMoreTables(int total) {
    final current = state.length;
    if (total <= current) return;
    final extra = [
      for (var n = current + 1; n <= total; n++)
        RestaurantTable(id: 't$n', number: n, capacity: 2),
    ];
    state = [...state, ...extra];
  }
}

final tablesProvider =
    StateNotifierProvider<TablesNotifier, List<RestaurantTable>>(
        (ref) => TablesNotifier());
