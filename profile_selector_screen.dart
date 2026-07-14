import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/product.dart';
import '../demo_data.dart';

class ProductsNotifier extends StateNotifier<List<Product>> {
  ProductsNotifier() : super(DemoData.products());

  /// Activa/desactiva temporalmente la disponibilidad de un producto.
  void toggleAvailability(String productId) {
    state = [
      for (final p in state)
        if (p.id == productId) p.copyWith(available: !p.available) else p,
    ];
  }
}

final productsProvider =
    StateNotifierProvider<ProductsNotifier, List<Product>>(
        (ref) => ProductsNotifier());
