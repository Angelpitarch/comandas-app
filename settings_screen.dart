/// Enumeraciones centrales del dominio.
/// Se definen aqui para que toda la app comparta un unico vocabulario.

/// Roles / perfiles de usuario.
enum UserRole {
  admin,
  mesero,
  cocina;

  String get label => switch (this) {
        UserRole.admin => 'Administrador',
        UserRole.mesero => 'Mesero / Cajero',
        UserRole.cocina => 'Cocina',
      };
}

/// Moneda en la que se expresa un monto.
enum Currency {
  usd,
  ves;

  String get symbol => this == Currency.usd ? '\$' : 'Bs';
  String get code => this == Currency.usd ? 'USD' : 'VES';
}

/// Categorias de producto (Etapa 1). En etapas futuras seran datos editables.
enum ProductCategory {
  hamburguesas,
  perrosCalientes,
  papas,
  bebidas,
  combos,
  otros;

  String get label => switch (this) {
        ProductCategory.hamburguesas => 'Hamburguesas',
        ProductCategory.perrosCalientes => 'Perros calientes',
        ProductCategory.papas => 'Papas',
        ProductCategory.bebidas => 'Bebidas',
        ProductCategory.combos => 'Combos',
        ProductCategory.otros => 'Otros',
      };
}

/// Tipo de producto. Diferencia comida de bebidas y combos para el futuro
/// control de inventario y recetas.
enum ProductType {
  comida,
  bebidaUnidad,
  bebidaTamano,
  combo;
}

/// Estados de una mesa. El estado visible se deriva de sus comandas abiertas.
enum TableStatus {
  disponible,
  ocupada,
  pedidoEnviado,
  pedidoListo,
  solicitandoCuenta,
  pendientePago;

  String get label => switch (this) {
        TableStatus.disponible => 'Disponible',
        TableStatus.ocupada => 'Ocupada',
        TableStatus.pedidoEnviado => 'Pedido enviado',
        TableStatus.pedidoListo => 'Pedido listo',
        TableStatus.solicitandoCuenta => 'Solicitando cuenta',
        TableStatus.pendientePago => 'Pendiente de pago',
      };
}

/// Estado de una comanda de cocina.
enum TicketStatus {
  nueva,
  preparando,
  lista,
  entregada,
  anulada;

  String get label => switch (this) {
        TicketStatus.nueva => 'Nueva',
        TicketStatus.preparando => 'Preparando',
        TicketStatus.lista => 'Lista',
        TicketStatus.entregada => 'Entregada',
        TicketStatus.anulada => 'Anulada',
      };
}

/// Tipo de comanda: la primera de la mesa o una adicion posterior.
enum TicketType {
  normal,
  adicion;
}

/// Tipo de servicio del pedido.
enum ServiceType {
  mesa,
  paraLlevar,
  delivery; // preparado para el futuro, no usado aun

  String get label => switch (this) {
        ServiceType.mesa => 'En mesa',
        ServiceType.paraLlevar => 'Para llevar',
        ServiceType.delivery => 'Delivery',
      };
}
