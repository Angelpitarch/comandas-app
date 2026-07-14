import '../domain/enums.dart';
import '../domain/models/money.dart';
import '../domain/models/product.dart';
import '../domain/models/restaurant_table.dart';
import '../domain/models/ticket.dart';
import '../domain/models/user.dart';

/// Datos de demostracion para la Etapa 1 (todo en memoria).
class DemoData {
  static const users = <AppUser>[
    AppUser(id: 'u1', name: 'Ana (Admin)', pin: '1111', role: UserRole.admin),
    AppUser(id: 'u2', name: 'Luis (Mesero)', pin: '2222', role: UserRole.mesero),
    AppUser(id: 'u3', name: 'Cocina', pin: '3333', role: UserRole.cocina),
  ];

  static const _tamanos = <ProductSize>[
    ProductSize(id: 's-p', name: 'Pequena', priceDelta: -0.5),
    ProductSize(id: 's-m', name: 'Mediana', priceDelta: 0),
    ProductSize(id: 's-g', name: 'Grande', priceDelta: 0.8),
  ];

  static List<Product> products() => [
        // Hamburguesas (precio base en USD)
        const Product(
          id: 'p1',
          category: ProductCategory.hamburguesas,
          type: ProductType.comida,
          name: 'Hamburguesa Completa',
          emoji: '🍔',
          basePrice: Money.usd(4.50),
          removableIngredients: ['Cebolla', 'Tomate', 'Lechuga', 'Salsas'],
          extras: [
            ProductExtra(id: 'e1', name: 'Queso adicional', price: 0.8),
            ProductExtra(id: 'e2', name: 'Tocineta', price: 1.0),
            ProductExtra(id: 'e3', name: 'Huevo', price: 0.7),
          ],
        ),
        const Product(
          id: 'p2',
          category: ProductCategory.hamburguesas,
          type: ProductType.comida,
          name: 'Hamburguesa Doble Carne',
          emoji: '🍔',
          basePrice: Money.usd(6.00),
          removableIngredients: ['Cebolla', 'Tomate', 'Lechuga'],
          extras: [
            ProductExtra(id: 'e1', name: 'Queso adicional', price: 0.8),
            ProductExtra(id: 'e2', name: 'Tocineta', price: 1.0),
          ],
        ),
        // Perros calientes
        const Product(
          id: 'p3',
          category: ProductCategory.perrosCalientes,
          type: ProductType.comida,
          name: 'Perro Caliente Especial',
          emoji: '🌭',
          basePrice: Money.usd(3.50),
          removableIngredients: ['Cebolla', 'Papitas', 'Salsas'],
          extras: [
            ProductExtra(id: 'e4', name: 'Queso', price: 0.6),
            ProductExtra(id: 'e5', name: 'Maiz', price: 0.5),
          ],
        ),
        // Papas
        const Product(
          id: 'p4',
          category: ProductCategory.papas,
          type: ProductType.comida,
          name: 'Papas Fritas',
          emoji: '🍟',
          basePrice: Money.usd(2.50),
          sizes: _tamanos,
          extras: [
            ProductExtra(id: 'e6', name: 'Queso cheddar', price: 0.8),
          ],
        ),
        // Bebidas por unidad (precio base en Bs para demostrar doble moneda)
        const Product(
          id: 'p5',
          category: ProductCategory.bebidas,
          type: ProductType.bebidaUnidad,
          name: 'Refresco en Lata',
          emoji: '🥤',
          basePrice: Money.ves(45.0),
        ),
        const Product(
          id: 'p6',
          category: ProductCategory.bebidas,
          type: ProductType.bebidaUnidad,
          name: 'Agua Mineral',
          emoji: '💧',
          basePrice: Money.ves(30.0),
        ),
        // Bebidas por tamano
        const Product(
          id: 'p7',
          category: ProductCategory.bebidas,
          type: ProductType.bebidaTamano,
          name: 'Jugo Natural',
          emoji: '🧃',
          basePrice: Money.usd(2.00),
          sizes: _tamanos,
        ),
        const Product(
          id: 'p8',
          category: ProductCategory.bebidas,
          type: ProductType.bebidaTamano,
          name: 'Batido',
          emoji: '🥛',
          basePrice: Money.usd(2.80),
          sizes: _tamanos,
        ),
        // Combos
        const Product(
          id: 'p9',
          category: ProductCategory.combos,
          type: ProductType.combo,
          name: 'Combo Hamburguesa + Papas + Refresco',
          emoji: '🍔🍟',
          basePrice: Money.usd(7.50),
          removableIngredients: ['Cebolla', 'Tomate'],
        ),
        // Otros
        const Product(
          id: 'p10',
          category: ProductCategory.otros,
          type: ProductType.comida,
          name: 'Tequenos (6 und)',
          emoji: '🧀',
          basePrice: Money.usd(3.00),
        ),
      ];

  static List<RestaurantTable> tables() => List.generate(12, (i) {
        final n = i + 1;
        return RestaurantTable(
          id: 't$n',
          number: n,
          capacity: n.isEven ? 4 : 2,
        );
      });

  /// Una comanda de ejemplo ya presente en cocina, para ver el tablero.
  static List<Ticket> tickets() => [
        Ticket(
          id: 'demo-tk',
          number: 1,
          type: TicketType.normal,
          serviceType: ServiceType.mesa,
          tableNumber: 5,
          waiterName: 'Luis (Mesero)',
          sentAt: DateTime.now().subtract(const Duration(minutes: 4)),
          status: TicketStatus.preparando,
          generalNote: 'Entregar bebidas primero',
          lines: const [
            TicketLine(
              productName: 'Hamburguesa Completa',
              quantity: 2,
              removedIngredients: ['Cebolla'],
              extras: ['Queso adicional'],
            ),
            TicketLine(productName: 'Papas Fritas', quantity: 1, sizeName: 'Grande'),
            TicketLine(productName: 'Refresco en Lata', quantity: 2),
          ],
        ),
      ];
}
