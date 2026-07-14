// Comandas - Puesto de Comida (Etapa 1: prototipo, un solo archivo)
// Sin dependencias externas: solo Flutter. Datos en memoria (se reinician al cerrar).
import 'dart:async';
import 'package:flutter/material.dart';

void main() => runApp(const ComandasApp());

// ======================= MODELOS =======================
enum Currency { usd, ves }
extension CurCode on Currency { String get code => this == Currency.usd ? 'USD' : 'VES'; }

enum Cat { hamburguesas, perros, papas, bebidas, combos, otros }
String catLabel(Cat c) => switch (c) {
      Cat.hamburguesas => 'Hamburguesas',
      Cat.perros => 'Perros calientes',
      Cat.papas => 'Papas',
      Cat.bebidas => 'Bebidas',
      Cat.combos => 'Combos',
      Cat.otros => 'Otros',
    };

class Extra {
  String id;
  String name;
  double price;
  Extra(this.id, this.name, this.price);
}

class Sz {
  String name;
  double delta;
  Sz(this.name, this.delta);
}

class Product {
  String id;
  String name;
  String emoji;
  Cat cat;
  double price;
  Currency cur;
  List<Sz> sizes;
  List<Extra> extras;
  List<String> quita;
  bool available;
  Product(this.id, this.name, this.emoji, this.cat, this.price, this.cur,
      {this.sizes = const [], this.extras = const [], this.quita = const [], this.available = true});
}

class CartItem {
  final Product p;
  int qty;
  Sz? size;
  Set<String> extras;
  Set<String> quita;
  String? note;
  CartItem(this.p, {this.qty = 1, this.size, Set<String>? extras, Set<String>? quita, this.note})
      : extras = extras ?? {},
        quita = quita ?? {};

  double unit() {
    var t = p.price + (size?.delta ?? 0);
    for (final e in p.extras) { if (extras.contains(e.id)) t += e.price; }
    return t;
  }

  CartItem clone() => CartItem(p, qty: qty, size: size, extras: {...extras}, quita: {...quita}, note: note);
}

class TableModel {
  final int number;
  final int cap;
  String status; // disponible, ocupada
  String? waiter;
  DateTime? openedAt;
  int guests;
  TableModel(this.number, this.cap, {this.status = 'disponible', this.waiter, this.openedAt, this.guests = 1});
}

class TLine {
  final String name;
  final int qty;
  final String? size;
  final List<String> extras;
  final List<String> quita;
  final String? note;
  const TLine(this.name, this.qty, {this.size, this.extras = const [], this.quita = const [], this.note});
}

class Ticket {
  final int number;
  final int? table;
  final String waiter;
  final DateTime sentAt;
  String status; // nueva, preparando, lista, entregada, anulada
  final List<TLine> lines;
  final String? note;
  final bool adicion;
  bool reprinted;
  Ticket(this.number, this.table, this.waiter, this.sentAt, this.status, this.lines,
      {this.note, this.adicion = false, this.reprinted = false});
}

class Payment {
  final String method;
  final double amountUsd;
  Payment(this.method, this.amountUsd);
}

class SaleLine {
  final String name;
  final int qty;
  final double lineUsd;
  SaleLine(this.name, this.qty, this.lineUsd);
}

class Sale {
  final int? table;
  final DateTime at;
  final List<SaleLine> lines;
  final double totalUsd;
  final List<Payment> payments;
  Sale(this.table, this.at, this.lines, this.totalUsd, this.payments);
}

// ======================= STORE =======================
class Store extends ChangeNotifier {
  double rate = 36.5; // Bs por 1 USD
  final List<Product> products = _demoProducts();
  final List<TableModel> tables = List.generate(12, (i) => TableModel(i + 1, i.isEven ? 2 : 4));
  final List<Ticket> tickets = [_demoTicket()];
  final List<Sale> sales = [];
  final List<String> methods = ['Efectivo Bs', 'Efectivo USD', 'Pago movil', 'Tarjeta'];
  int _no = 2;
  int _pid = 100;
  final Map<String, List<CartItem>> _carts = {};
  final Map<int, List<CartItem>> _accounts = {};
  String currentUser = '';

  List<CartItem> cart(String key) => _carts.putIfAbsent(key, () => []);
  List<CartItem> account(int n) => _accounts.putIfAbsent(n, () => []);

  double toUsd(double amt, Currency c) => c == Currency.usd ? amt : amt / rate;
  double toVes(double amt, Currency c) => c == Currency.ves ? amt : amt * rate;
  double lineUsd(CartItem it) => toUsd(it.unit(), it.p.cur) * it.qty;
  double cartTotalUsd(String key) => cart(key).fold(0.0, (s, it) => s + lineUsd(it));
  int cartCount(String key) => cart(key).fold(0, (s, it) => s + it.qty);
  double accountTotalUsd(int n) => account(n).fold(0.0, (s, it) => s + lineUsd(it));

  void touch() => notifyListeners();
  void setRate(double r) { rate = r; notifyListeners(); }
  void toggleProduct(Product p) { p.available = !p.available; notifyListeners(); }

  String newProductId() => 'p${_pid++}';
  void addProduct(Product p) { products.add(p); notifyListeners(); }
  void updateProduct() { notifyListeners(); }
  void deleteProduct(Product p) { products.remove(p); notifyListeners(); }

  void openTable(int n) {
    final t = tables.firstWhere((e) => e.number == n);
    if (t.status == 'disponible') {
      t.status = 'ocupada';
      t.waiter = currentUser;
      t.openedAt = DateTime.now();
    }
    notifyListeners();
  }

  Ticket? send(String key, {int? table, String? note, bool keepCart = false}) {
    final items = cart(key);
    if (items.isEmpty) return null;
    final adicion = table != null && tickets.any((t) => t.table == table && t.status != 'anulada');
    final lines = [
      for (final it in items)
        TLine(it.p.name, it.qty,
            size: it.size?.name,
            extras: [for (final e in it.p.extras) if (it.extras.contains(e.id)) e.name],
            quita: it.quita.toList(),
            note: it.note)
    ];
    final tk = Ticket(_no++, table, currentUser, DateTime.now(), 'nueva', lines, note: note, adicion: adicion);
    tickets.insert(0, tk);
    if (table != null) {
      tables.firstWhere((e) => e.number == table).status = 'ocupada';
      for (final it in items) { account(table).add(it.clone()); }
    }
    if (!keepCart) items.clear();
    notifyListeners();
    return tk;
  }

  void advance(Ticket t) {
    t.status = switch (t.status) {
      'nueva' => 'preparando',
      'preparando' => 'lista',
      'lista' => 'entregada',
      _ => t.status,
    };
    notifyListeners();
  }

  void cancel(Ticket t) { t.status = 'anulada'; notifyListeners(); }
  void reprint(Ticket t) { t.reprinted = true; notifyListeners(); }

  List<Ticket> ticketsOf(int n) =>
      tickets.where((x) => x.table == n && x.status != 'anulada').toList();

  String tableStatus(int n) {
    final t = tables.firstWhere((e) => e.number == n);
    if (t.status == 'disponible') return 'disponible';
    final tk = tickets.where((x) => x.table == n && x.status != 'anulada' && x.status != 'entregada').toList();
    if (tk.any((x) => x.status == 'lista')) return 'listo';
    if (tk.isNotEmpty) return 'cocina';
    if (account(n).isNotEmpty) return 'servido';
    return 'ocupada';
  }

  void pay(List<Payment> payments, {int? table, String? cartKey}) {
    final items = table != null ? account(table) : cart(cartKey ?? '');
    if (items.isEmpty) return;
    final lines = [for (final it in items) SaleLine(it.p.name, it.qty, lineUsd(it))];
    final totalUsd = lines.fold(0.0, (s, l) => s + l.lineUsd);
    sales.insert(0, Sale(table, DateTime.now(), lines, totalUsd, payments));
    items.clear();
    if (table != null) {
      final t = tables.firstWhere((e) => e.number == table);
      t.status = 'disponible';
      t.waiter = null;
      t.openedAt = null;
      for (final tk in tickets) {
        if (tk.table == table && tk.status != 'anulada') tk.status = 'entregada';
      }
    }
    notifyListeners();
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  List<Sale> get todaySales => sales.where((s) => _sameDay(s.at, DateTime.now())).toList();
  double get todayTotalUsd => todaySales.fold(0.0, (s, e) => s + e.totalUsd);
  Map<String, int> unitsToday() {
    final m = <String, int>{};
    for (final s in todaySales) { for (final l in s.lines) { m[l.name] = (m[l.name] ?? 0) + l.qty; } }
    return m;
  }
  Map<String, double> byMethodToday() {
    final m = <String, double>{};
    for (final s in todaySales) { for (final p in s.payments) { m[p.method] = (m[p.method] ?? 0) + p.amountUsd; } }
    return m;
  }
}

final store = Store();

List<Product> _demoProducts() => [
      Product('p1', 'Hamburguesa Completa', '🍔', Cat.hamburguesas, 4.50, Currency.usd,
          quita: ['Cebolla', 'Tomate', 'Lechuga', 'Salsas'],
          extras: [Extra('e1', 'Queso adicional', 0.8), Extra('e2', 'Tocineta', 1.0), Extra('e3', 'Huevo', 0.7)]),
      Product('p2', 'Hamburguesa Doble', '🍔', Cat.hamburguesas, 6.00, Currency.usd,
          quita: ['Cebolla', 'Tomate'],
          extras: [Extra('e1', 'Queso adicional', 0.8), Extra('e2', 'Tocineta', 1.0)]),
      Product('p3', 'Perro Caliente Especial', '🌭', Cat.perros, 3.50, Currency.usd,
          quita: ['Cebolla', 'Papitas', 'Salsas'],
          extras: [Extra('e4', 'Queso', 0.6), Extra('e5', 'Maiz', 0.5)]),
      Product('p4', 'Papas Fritas', '🍟', Cat.papas, 2.50, Currency.usd,
          sizes: [Sz('Pequena', -0.5), Sz('Mediana', 0), Sz('Grande', 0.8)],
          extras: [Extra('e6', 'Queso cheddar', 0.8)]),
      Product('p5', 'Refresco en Lata', '🥤', Cat.bebidas, 45.0, Currency.ves),
      Product('p6', 'Agua Mineral', '💧', Cat.bebidas, 30.0, Currency.ves),
      Product('p7', 'Jugo Natural', '🧃', Cat.bebidas, 2.00, Currency.usd,
          sizes: [Sz('Pequena', -0.4), Sz('Mediana', 0), Sz('Grande', 0.6)]),
      Product('p8', 'Batido', '🥛', Cat.bebidas, 2.80, Currency.usd,
          sizes: [Sz('Pequena', -0.4), Sz('Mediana', 0), Sz('Grande', 0.6)]),
      Product('p9', 'Combo Hamburguesa+Papas+Refresco', '🍔', Cat.combos, 7.50, Currency.usd,
          quita: ['Cebolla', 'Tomate']),
      Product('p10', 'Tequenos (6 und)', '🧀', Cat.otros, 3.00, Currency.usd),
    ];

Ticket _demoTicket() => Ticket(1, 5, 'Luis (Mesero)',
    DateTime.now().subtract(const Duration(minutes: 4)), 'preparando', const [
  TLine('Hamburguesa Completa', 2, extras: ['Queso adicional'], quita: ['Cebolla']),
  TLine('Papas Fritas', 1, size: 'Grande'),
  TLine('Refresco en Lata', 2),
], note: 'Entregar bebidas primero');

// ======================= FORMATO DE DINERO =======================
String _grp(String s) {
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}
String _fmt(double v, {int dec = 2}) {
  final f = v.abs().toStringAsFixed(dec);
  final parts = f.split('.');
  final g = _grp(parts[0]);
  return dec == 0 ? g : '$g,${parts[1]}';
}
String usd(double v) => '\$${_fmt(v)}';
String ves(double v) => 'Bs ${_fmt(v)}';
String dualUsd(double u) => '${usd(u)} · ${ves(u * store.rate)}';
String dualPrice(double amt, Currency c) => '${usd(store.toUsd(amt, c))} · ${ves(store.toVes(amt, c))}';
String two(int n) => n.toString().padLeft(2, '0');
String hhmm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

// ======================= APP / TEMA =======================
const kPrimary = Color(0xFFD84315);

class ComandasApp extends StatelessWidget {
  const ComandasApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Comandas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: kPrimary, primary: kPrimary),
        scaffoldBackgroundColor: const Color(0xFFFFF8F3),
        appBarTheme: const AppBarTheme(backgroundColor: kPrimary, foregroundColor: Colors.white),
      ),
      home: const LoginScreen(),
    );
  }
}

Color statusColor(String s) => switch (s) {
      'disponible' => const Color(0xFF66BB6A),
      'ocupada' => const Color(0xFFFFA726),
      'cocina' => const Color(0xFF42A5F5),
      'listo' => const Color(0xFF26C6DA),
      'servido' => const Color(0xFFAB47BC),
      _ => const Color(0xFF90A4AE),
    };
String statusLabel(String s) => switch (s) {
      'disponible' => 'Disponible',
      'ocupada' => 'Ocupada',
      'cocina' => 'En cocina',
      'listo' => 'Pedido listo',
      'servido' => 'Servido',
      _ => s,
    };

// ======================= LOGIN =======================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  String _pin = '';
  String? _err;
  static const _users = {'1111': 'Ana (Admin)', '2222': 'Luis (Mesero)', '3333': 'Cocina'};

  void _tap(String d) {
    if (_pin.length >= 4) return;
    setState(() { _pin += d; _err = null; });
    if (_pin.length == 4) {
      final name = _users[_pin];
      if (name == null) {
        setState(() { _err = 'PIN incorrecto'; _pin = ''; });
      } else {
        store.currentUser = name;
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
        setState(() => _pin = '');
      }
    }
  }
  void _back() { if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1)); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.lunch_dining, size: 72, color: kPrimary),
                  const SizedBox(height: 8),
                  const Text('Comandas', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                  const Text('Ingresa tu PIN'),
                  const SizedBox(height: 20),
                  Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          width: 18, height: 18,
                          decoration: BoxDecoration(shape: BoxShape.circle,
                              color: i < _pin.length ? kPrimary : Colors.transparent,
                              border: Border.all(color: kPrimary, width: 2)),
                        ))),
                  SizedBox(height: 24, child: Text(_err ?? '', style: const TextStyle(color: Colors.red))),
                  _keypad(),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(12)),
                    child: const Text('PIN de prueba:\nAdmin 1111 · Mesero 2222 · Cocina 3333',
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
  Widget _k(String label, {VoidCallback? action, Widget? child}) => Padding(
        padding: const EdgeInsets.all(6),
        child: SizedBox(width: 72, height: 62,
          child: FilledButton.tonal(onPressed: action ?? () => _tap(label),
              child: child ?? Text(label, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)))),
      );
  Widget _keypad() => Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [_k('1'), _k('2'), _k('3')]),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [_k('4'), _k('5'), _k('6')]),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [_k('7'), _k('8'), _k('9')]),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const SizedBox(width: 84), _k('0'),
          _k('', action: _back, child: const Icon(Icons.backspace_outlined)),
        ]),
      ]);
}

// ======================= SELECTOR DE PERFIL =======================
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    Widget card(IconData ic, String t, Color c, Widget dest) => SizedBox(
          width: 200, height: 170,
          child: Card(child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => dest)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              CircleAvatar(radius: 38, backgroundColor: c.withOpacity(0.15), child: Icon(ic, size: 40, color: c)),
              const SizedBox(height: 14),
              Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ]),
          )),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Selecciona un perfil')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Hola, ${store.currentUser}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('Modo prueba: puedes entrar a cualquier perfil.', textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Wrap(spacing: 16, runSpacing: 16, alignment: WrapAlignment.center, children: [
              card(Icons.admin_panel_settings, 'Administrador', const Color(0xFF5E35B1), const AdminScreen()),
              card(Icons.room_service, 'Mesero / Cajero', const Color(0xFF00897B), const TablesScreen()),
              card(Icons.soup_kitchen, 'Cocina', const Color(0xFFD84315), const KitchenScreen()),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ======================= MESAS =======================
class TablesScreen extends StatelessWidget {
  const TablesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mesas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const OrderScreen(cartKey: 'llevar', table: null))),
        icon: const Icon(Icons.takeout_dining),
        label: const Text('Para llevar'),
      ),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) => LayoutBuilder(builder: (context, cns) {
          final cols = (cns.maxWidth / 180).floor().clamp(2, 6).toInt();
          return GridView.builder(
            padding: const EdgeInsets.all(14),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.0),
            itemCount: store.tables.length,
            itemBuilder: (context, i) {
              final t = store.tables[i];
              final st = store.tableStatus(t.number);
              final total = store.accountTotalUsd(t.number);
              final c = statusColor(st);
              return Card(
                child: InkWell(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => TableDetailScreen(table: t.number))),
                  child: Container(
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: c, width: 6))),
                    padding: const EdgeInsets.all(10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text('Mesa ${t.number}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Icon(Icons.event_seat, size: 15, color: Colors.grey[600]),
                        Text(' ${t.cap}', style: TextStyle(color: Colors.grey[600])),
                      ]),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: c.withOpacity(0.18), borderRadius: BorderRadius.circular(20)),
                        child: Text(statusLabel(st), style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 11.5)),
                      ),
                      const Spacer(),
                      if (t.waiter != null)
                        Text(t.waiter!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5)),
                      if (total > 0)
                        Text('Cuenta: ${usd(total)}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

// ======================= DETALLE DE MESA =======================
class TableDetailScreen extends StatelessWidget {
  final int table;
  const TableDetailScreen({super.key, required this.table});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Mesa $table')),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final acc = store.account(table);
          final tk = store.ticketsOf(table);
          final total = store.accountTotalUsd(table);
          final t = store.tables.firstWhere((e) => e.number == table);
          return Column(children: [
            Expanded(
              child: ListView(padding: const EdgeInsets.all(14), children: [
                // Estado de comandas en cocina
                if (tk.isNotEmpty) ...[
                  const Text('Estado en cocina', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  for (final k in tk)
                    Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(backgroundColor: _kColor(k.status).withOpacity(0.18),
                            child: Icon(_kIcon(k.status), color: _kColor(k.status), size: 20)),
                        title: Text('Comanda #${k.number.toString().padLeft(6, '0')}'
                            '${k.adicion ? '  (ADICION)' : ''}'),
                        subtitle: Text('${k.lines.length} productos · enviada ${hhmm(k.sentAt)}'),
                        trailing: Text(_kLabel(k.status),
                            style: TextStyle(color: _kColor(k.status), fontWeight: FontWeight.w600)),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
                // Lo pedido (cuenta)
                const Text('Lo pedido en esta mesa', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                if (acc.isEmpty)
                  const Padding(padding: EdgeInsets.all(12),
                      child: Text('Aun no hay productos. Toca "Agregar productos".', style: TextStyle(color: Colors.grey)))
                else
                  for (final it in acc)
                    Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(radius: 14, backgroundColor: Colors.orange.shade50,
                            child: Text('${it.qty}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        title: Text(it.p.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                        subtitle: Text([
                          if (it.size != null) it.size!.name,
                          ...it.p.extras.where((e) => it.extras.contains(e.id)).map((e) => '+${e.name}'),
                          ...it.quita.map((q) => 'Sin $q'),
                          if (it.note != null) 'Nota: ${it.note}',
                        ].join(' · '), style: const TextStyle(fontSize: 11)),
                        trailing: Text(usd(store.lineUsd(it)), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ),
                    ),
              ]),
            ),
            Material(
              elevation: 8,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      const Text('Total mesa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text(dualUsd(total), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) {
                            store.openTable(table);
                            return OrderScreen(cartKey: 'mesa-$table', table: table);
                          })),
                          icon: const Icon(Icons.add),
                          label: const Text('Agregar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: acc.isEmpty ? null : () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => ReceiptScreen(table: table))),
                          icon: const Icon(Icons.receipt_long),
                          label: const Text('Comprobante'),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity, height: 50,
                      child: FilledButton.icon(
                        onPressed: acc.isEmpty ? null : () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => PaymentScreen(table: table))),
                        icon: const Icon(Icons.point_of_sale),
                        label: const Text('Cobrar'),
                      ),
                    ),
                    if (t.status == 'disponible')
                      const Padding(padding: EdgeInsets.only(top: 6),
                          child: Text('Mesa disponible', style: TextStyle(fontSize: 11, color: Colors.grey))),
                  ]),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

Color _kColor(String s) => switch (s) {
      'nueva' => const Color(0xFF42A5F5),
      'preparando' => const Color(0xFFFFA726),
      'lista' => const Color(0xFF26C6DA),
      'entregada' => const Color(0xFF66BB6A),
      _ => Colors.grey,
    };
IconData _kIcon(String s) => switch (s) {
      'nueva' => Icons.fiber_new,
      'preparando' => Icons.outdoor_grill,
      'lista' => Icons.room_service,
      'entregada' => Icons.check_circle,
      _ => Icons.cancel,
    };
String _kLabel(String s) => switch (s) {
      'nueva' => 'Recibida',
      'preparando' => 'Preparando',
      'lista' => 'Lista',
      'entregada' => 'Entregada',
      _ => s,
    };

// ======================= PEDIDO (menu) =======================
class OrderScreen extends StatefulWidget {
  final String cartKey;
  final int? table;
  const OrderScreen({super.key, required this.cartKey, required this.table});
  @override
  State<OrderScreen> createState() => _OrderScreenState();
}
class _OrderScreenState extends State<OrderScreen> {
  Cat _cat = Cat.hamburguesas;
  bool _sending = false;
  bool _sentTakeaway = false;
  final _noteCtrl = TextEditingController();

  @override
  void dispose() { _noteCtrl.dispose(); super.dispose(); }

  Future<void> _addOrEdit(Product p, {CartItem? existing}) async {
    final item = await showModalBottomSheet<CartItem>(
      context: context, isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => ItemEditor(product: p, existing: existing),
    );
    if (item != null && existing == null) { store.cart(widget.cartKey).add(item); store.touch(); }
    else if (item != null) { store.touch(); }
  }

  Future<void> _send() async {
    if (_sending) return;
    if (store.cart(widget.cartKey).isEmpty) return;
    setState(() => _sending = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    final tk = store.send(widget.cartKey, table: widget.table, note: note, keepCart: widget.table == null);
    if (!mounted) return;
    setState(() { _sending = false; if (widget.table == null) _sentTakeaway = true; });
    _noteCtrl.clear();
    if (tk == null) return;
    if (widget.table != null) {
      await showDialog<void>(context: context, builder: (_) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: Text('Comanda #${tk.number.toString().padLeft(6, '0')}'),
        content: Text(tk.adicion ? 'ADICION enviada a cocina (Mesa ${tk.table}).' : 'Comanda enviada a cocina.'),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido'))],
      ));
      if (mounted) Navigator.pop(context); // volver al detalle de la mesa
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enviado a cocina')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.table != null ? 'Agregar - Mesa ${widget.table}' : 'Para llevar';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final items = store.cart(widget.cartKey);
          final total = store.cartTotalUsd(widget.cartKey);
          return Column(children: [
            SizedBox(
              height: 52,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  for (final c in Cat.values)
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Center(child: ChoiceChip(label: Text(catLabel(c)), selected: c == _cat,
                          onSelected: (_) => setState(() => _cat = c)))),
                ]),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 190, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.9),
                itemCount: store.products.where((p) => p.cat == _cat).length,
                itemBuilder: (context, i) {
                  final p = store.products.where((e) => e.cat == _cat).toList()[i];
                  return Card(
                    child: InkWell(
                      onTap: p.available ? () => _addOrEdit(p) : null,
                      child: Opacity(
                        opacity: p.available ? 1 : 0.4,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Center(child: Text(p.emoji, style: const TextStyle(fontSize: 38))),
                            const Spacer(),
                            Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600, height: 1.1, fontSize: 13)),
                            const SizedBox(height: 3),
                            Text(dualPrice(p.price, p.cur), style: const TextStyle(fontSize: 10.5)),
                            if (!p.available) const Text('No disponible', style: TextStyle(color: Colors.red, fontSize: 10)),
                          ]),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Material(
              elevation: 8,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (items.isNotEmpty)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 150),
                        child: ListView(shrinkWrap: true, children: [
                          for (final it in items)
                            Dismissible(
                              key: ValueKey(it),
                              direction: DismissDirection.endToStart,
                              background: Container(color: Colors.red, alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 16), child: const Icon(Icons.delete, color: Colors.white)),
                              onDismissed: (_) { items.remove(it); store.touch(); },
                              child: ListTile(
                                dense: true,
                                leading: CircleAvatar(radius: 14, backgroundColor: Colors.orange.shade50,
                                    child: Text('${it.qty}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                title: Text(it.p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                subtitle: Text([
                                  if (it.size != null) it.size!.name,
                                  ...it.p.extras.where((e) => it.extras.contains(e.id)).map((e) => '+${e.name}'),
                                  ...it.quita.map((q) => 'Sin $q'),
                                  if (it.note != null) 'Nota: ${it.note}',
                                ].join(' · '), style: const TextStyle(fontSize: 11)),
                                trailing: Text(usd(store.lineUsd(it)), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                onTap: () => _addOrEdit(it.p, existing: it),
                              ),
                            ),
                        ]),
                      )
                    else
                      const Padding(padding: EdgeInsets.all(8), child: Text('Agrega productos del menu', style: TextStyle(color: Colors.grey))),
                    TextField(
                      controller: _noteCtrl,
                      decoration: const InputDecoration(isDense: true, labelText: 'Observacion general',
                        hintText: 'Ej: entregar bebidas primero', border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.sticky_note_2_outlined)),
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text(dualUsd(total), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 8),
                    if (widget.table != null)
                      SizedBox(width: double.infinity, height: 50,
                        child: FilledButton.icon(
                          onPressed: (items.isEmpty || _sending) ? null : _send,
                          icon: _sending
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.send),
                          label: Text(_sending ? 'Enviando...' : 'Enviar a cocina'),
                        ),
                      )
                    else
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: (items.isEmpty || _sending) ? null : _send,
                            icon: const Icon(Icons.send),
                            label: Text(_sentTakeaway ? 'Enviar de nuevo' : 'Enviar a cocina'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: items.isEmpty ? null : () async {
                              await Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => PaymentScreen(table: null, cartKey: widget.cartKey)));
                              if (mounted && store.cart(widget.cartKey).isEmpty) Navigator.pop(context);
                            },
                            icon: const Icon(Icons.point_of_sale),
                            label: const Text('Cobrar'),
                          ),
                        ),
                      ]),
                  ]),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

// ======================= EDITOR DE ITEM =======================
class ItemEditor extends StatefulWidget {
  final Product product;
  final CartItem? existing;
  const ItemEditor({super.key, required this.product, this.existing});
  @override
  State<ItemEditor> createState() => _ItemEditorState();
}
class _ItemEditorState extends State<ItemEditor> {
  late Sz? _size;
  late int _qty;
  late Set<String> _extras;
  late Set<String> _quita;
  late TextEditingController _note;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    final e = widget.existing;
    _size = e?.size ?? (p.sizes.isNotEmpty ? p.sizes[1] : null);
    _qty = e?.qty ?? 1;
    _extras = {...?e?.extras};
    _quita = {...?e?.quita};
    _note = TextEditingController(text: e?.note ?? '');
  }
  @override
  void dispose() { _note.dispose(); super.dispose(); }

  double get _unit {
    final p = widget.product;
    var t = p.price + (_size?.delta ?? 0);
    for (final ex in p.extras) { if (_extras.contains(ex.id)) t += ex.price; }
    return t;
  }
  void _confirm() {
    final e = widget.existing;
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    if (e != null) {
      e.size = _size; e.qty = _qty; e.extras = _extras; e.quita = _quita; e.note = note;
      Navigator.pop(context, e);
    } else {
      Navigator.pop(context, CartItem(widget.product, qty: _qty, size: _size, extras: _extras, quita: _quita, note: note));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false, initialChildSize: 0.75, maxChildSize: 0.95, minChildSize: 0.5,
        builder: (context, scroll) => Column(children: [
          const SizedBox(height: 10),
          Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(4))),
          Expanded(
            child: ListView(controller: scroll, padding: const EdgeInsets.all(20), children: [
              Row(children: [
                Text(p.emoji, style: const TextStyle(fontSize: 30)),
                const SizedBox(width: 10),
                Expanded(child: Text(p.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold))),
              ]),
              const SizedBox(height: 4),
              Text(dualPrice(_unit, p.cur), style: const TextStyle(fontWeight: FontWeight.w600)),
              const Divider(height: 26),
              if (p.sizes.isNotEmpty) ...[
                const Text('Tamano', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  for (final s in p.sizes)
                    ChoiceChip(label: Text(s.name), selected: _size?.name == s.name, onSelected: (_) => setState(() => _size = s)),
                ]),
                const SizedBox(height: 16),
              ],
              if (p.extras.isNotEmpty) ...[
                const Text('Extras', style: TextStyle(fontWeight: FontWeight.w600)),
                for (final ex in p.extras)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero, dense: true,
                    value: _extras.contains(ex.id), title: Text(ex.name),
                    secondary: Text('+ ${usd(ex.price)}'),
                    onChanged: (v) => setState(() => v == true ? _extras.add(ex.id) : _extras.remove(ex.id)),
                  ),
                const SizedBox(height: 12),
              ],
              if (p.quita.isNotEmpty) ...[
                const Text('Quitar ingredientes', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  for (final ing in p.quita)
                    FilterChip(label: Text('Sin $ing'), selected: _quita.contains(ing),
                        onSelected: (v) => setState(() => v ? _quita.add(ing) : _quita.remove(ing))),
                ]),
                const SizedBox(height: 16),
              ],
              TextField(controller: _note, maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Observacion del producto', border: OutlineInputBorder())),
            ]),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(children: [
                Container(
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    IconButton(icon: const Icon(Icons.remove), onPressed: _qty > 1 ? () => setState(() => _qty--) : null),
                    Text('$_qty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.add), onPressed: () => setState(() => _qty++)),
                  ]),
                ),
                const SizedBox(width: 12),
                Expanded(child: FilledButton.icon(onPressed: _confirm, icon: const Icon(Icons.add_shopping_cart),
                    label: Text(widget.existing == null ? 'Agregar' : 'Guardar'))),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ======================= COBRO / PAGO =======================
class PaymentScreen extends StatefulWidget {
  final int? table;
  final String? cartKey;
  const PaymentScreen({super.key, this.table, this.cartKey});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}
class _PaymentScreenState extends State<PaymentScreen> {
  int _mode = 0; // 0 completa, 1 iguales, 2 por productos
  int _persons = 2;
  final Map<int, int> _assign = {}; // item index -> persona
  final Map<int, String> _method = {}; // parte index -> medio de pago

  List<CartItem> get _items =>
      widget.table != null ? store.account(widget.table!) : store.cart(widget.cartKey ?? '');
  double get _totalUsd => _items.fold(0.0, (s, it) => s + store.lineUsd(it));

  List<double> _parts() {
    if (_mode == 0) return [_totalUsd];
    if (_mode == 1) return List.filled(_persons, _totalUsd / _persons);
    final res = List.filled(_persons, 0.0);
    for (var i = 0; i < _items.length; i++) {
      final person = (_assign[i] ?? 0).clamp(0, _persons - 1).toInt();
      res[person] += store.lineUsd(_items[i]);
    }
    return res;
  }

  void _confirm() {
    final parts = _parts();
    final payments = <Payment>[];
    for (var i = 0; i < parts.length; i++) {
      if (parts[i] <= 0) continue;
      payments.add(Payment(_method[i] ?? store.methods.first, parts[i]));
    }
    if (payments.isEmpty) return;
    store.pay(payments, table: widget.table, cartKey: widget.cartKey);
    showDialog<void>(context: context, builder: (_) => AlertDialog(
      icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
      title: const Text('Cobro registrado'),
      content: Text(widget.table != null ? 'Mesa ${widget.table} liberada.' : 'Pedido para llevar cobrado.'),
      actions: [FilledButton(onPressed: () {
        final nav = Navigator.of(context);
        nav.pop(); // cierra dialogo
        nav.pop(); // cierra pantalla de cobro
        if (widget.table != null) nav.pop(); // cierra detalle de la mesa
      }, child: const Text('Listo'))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final parts = _parts();
    return Scaffold(
      appBar: AppBar(title: Text(widget.table != null ? 'Cobrar - Mesa ${widget.table}' : 'Cobrar - Para llevar')),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) => Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.all(14), children: [
              Card(child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  const Text('Total a cobrar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text(dualUsd(_totalUsd), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ]),
              )),
              const SizedBox(height: 6),
              const Text('Dividir la cuenta', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Completa')),
                  ButtonSegment(value: 1, label: Text('Iguales')),
                  ButtonSegment(value: 2, label: Text('Por productos')),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
              if (_mode != 0) ...[
                const SizedBox(height: 10),
                Row(children: [
                  const Text('Personas:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  IconButton(icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _persons > 2 ? () => setState(() => _persons--) : null),
                  Text('$_persons', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.add_circle_outline),
                      onPressed: _persons < 10 ? () => setState(() => _persons++) : null),
                ]),
              ],
              if (_mode == 2) ...[
                const Divider(),
                const Text('Asigna cada producto a una persona', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                for (var i = 0; i < _items.length; i++)
                  ListTile(
                    dense: true, contentPadding: EdgeInsets.zero,
                    title: Text('${_items[i].qty}  ${_items[i].p.name}', style: const TextStyle(fontSize: 13)),
                    subtitle: Text(usd(store.lineUsd(_items[i])), style: const TextStyle(fontSize: 11.5)),
                    trailing: DropdownButton<int>(
                      value: (_assign[i] ?? 0).clamp(0, _persons - 1).toInt(),
                      items: [for (var p = 0; p < _persons; p++)
                        DropdownMenuItem(value: p, child: Text('Persona ${p + 1}'))],
                      onChanged: (v) => setState(() => _assign[i] = v ?? 0),
                    ),
                  ),
              ],
              const Divider(height: 24),
              const Text('Pago', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              for (var i = 0; i < parts.length; i++)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(parts.length == 1 ? 'Monto' : 'Persona ${i + 1}',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text(dualUsd(parts[i]), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, children: [
                        for (final m in store.methods)
                          ChoiceChip(
                            label: Text(m, style: const TextStyle(fontSize: 12)),
                            selected: (_method[i] ?? store.methods.first) == m,
                            onSelected: (_) => setState(() => _method[i] = m),
                          ),
                      ]),
                    ]),
                  ),
                ),
            ]),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity, height: 52,
                child: FilledButton.icon(
                  onPressed: _items.isEmpty ? null : _confirm,
                  icon: const Icon(Icons.check),
                  label: const Text('Confirmar cobro'),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ======================= COMPROBANTE =======================
class ReceiptScreen extends StatelessWidget {
  final int table;
  const ReceiptScreen({super.key, required this.table});
  @override
  Widget build(BuildContext context) {
    final acc = store.account(table);
    final total = store.accountTotalUsd(table);
    final now = DateTime.now();
    const mono = TextStyle(fontFamily: 'monospace', fontSize: 13.5, height: 1.4, color: Colors.black);
    return Scaffold(
      appBar: AppBar(title: const Text('Comprobante')),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(18),
            constraints: const BoxConstraints(maxWidth: 360),
            color: Colors.white,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              const Center(child: Text('PUESTO DE COMIDA',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 15, fontWeight: FontWeight.bold))),
              const Center(child: Text('PRECUENTA (no fiscal)', style: mono)),
              const Text('------------------------------', style: mono),
              Text('MESA $table', style: mono.copyWith(fontWeight: FontWeight.bold)),
              Text('${two(now.day)}/${two(now.month)}/${now.year}  ${hhmm(now)}', style: mono),
              Text('MESERO: ${store.tables.firstWhere((e) => e.number == table).waiter ?? '-'}', style: mono),
              const Text('------------------------------', style: mono),
              for (final it in acc) ...[
                Text('${it.qty} x ${it.p.name}', style: mono.copyWith(fontWeight: FontWeight.w600)),
                if (it.size != null || it.extras.isNotEmpty || it.quita.isNotEmpty)
                  Text('   ${[
                    if (it.size != null) it.size!.name,
                    ...it.p.extras.where((e) => it.extras.contains(e.id)).map((e) => '+${e.name}'),
                    ...it.quita.map((q) => 'sin $q'),
                  ].join(', ')}', style: mono.copyWith(fontSize: 12)),
                Text('   ${usd(store.lineUsd(it))}   ${ves(store.lineUsd(it) * store.rate)}', style: mono),
              ],
              const Text('------------------------------', style: mono),
              Text('TOTAL: ${usd(total)}', style: mono.copyWith(fontWeight: FontWeight.bold, fontSize: 15)),
              Text('       ${ves(total * store.rate)}', style: mono.copyWith(fontWeight: FontWeight.bold)),
              Text('Tasa: ${ves(store.rate)} / \$', style: mono.copyWith(fontSize: 11)),
              const SizedBox(height: 14),
              Center(
                child: FilledButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Impresion por Bluetooth se agrega en la Entrega 4'))),
                  icon: const Icon(Icons.print),
                  label: const Text('Imprimir'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ======================= COCINA =======================
class KitchenScreen extends StatefulWidget {
  const KitchenScreen({super.key});
  @override
  State<KitchenScreen> createState() => _KitchenScreenState();
}
class _KitchenScreenState extends State<KitchenScreen> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() {}); });
  }
  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  String _elapsed(DateTime d) {
    final s = DateTime.now().difference(d);
    return '${(s.inMinutes).toString().padLeft(2, '0')}:${(s.inSeconds % 60).toString().padLeft(2, '0')}';
  }
  Color _c(String s) => switch (s) {
        'nueva' => const Color(0xFF42A5F5),
        'preparando' => const Color(0xFFFFA726),
        'lista' => const Color(0xFF66BB6A),
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF263238),
      appBar: AppBar(title: const Text('Cocina - Comandas')),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final list = store.tickets.where((t) => t.status != 'entregada' && t.status != 'anulada').toList();
          if (list.isEmpty) {
            return const Center(child: Text('Sin comandas pendientes', style: TextStyle(color: Colors.white70, fontSize: 18)));
          }
          return LayoutBuilder(builder: (context, cns) {
            final cols = (cns.maxWidth / 300).floor().clamp(1, 5).toInt();
            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.72),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final t = list[i];
                final c = _c(t.status);
                return Card(
                  color: Colors.white,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Container(
                      color: c,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(children: [
                        Text('#${t.number.toString().padLeft(6, '0')}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        const Spacer(),
                        const Icon(Icons.timer, color: Colors.white, size: 15),
                        const SizedBox(width: 3),
                        Text(_elapsed(t.sentAt), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(children: [
                        Text(t.table != null ? 'MESA ${t.table}' : 'PARA LLEVAR', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        if (t.adicion)
                          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), color: Colors.amber,
                              child: const Text('ADICION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      ]),
                    ),
                    Text(t.waiter, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                    const Divider(height: 10),
                    Expanded(
                      child: ListView(padding: const EdgeInsets.symmetric(horizontal: 12), children: [
                        for (final l in t.lines) ...[
                          Text('${l.qty}  ${l.name}${l.size != null ? ' (${l.size})' : ''}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          for (final e in l.extras) Text('   + $e', style: const TextStyle(fontSize: 12.5, color: Color(0xFF2E7D32))),
                          for (final q in l.quita) Text('   - Sin $q', style: const TextStyle(fontSize: 12.5, color: Colors.red)),
                          if (l.note != null) Text('   * ${l.note}', style: const TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic)),
                          const SizedBox(height: 3),
                        ],
                        if (t.note != null) ...[
                          const Divider(),
                          Text('OBS: ${t.note}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        ],
                        if (t.reprinted) const Center(child: Text('** REIMPRESION **', style: TextStyle(fontWeight: FontWeight.bold))),
                      ]),
                    ),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                      IconButton(tooltip: 'Reimprimir', icon: const Icon(Icons.print), onPressed: () {
                        store.reprint(t);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('REIMPRESION registrada (impresora real en Entrega 4)')));
                      }),
                      IconButton(tooltip: 'Anular', icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () => store.cancel(t)),
                    ]),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: SizedBox(width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: c),
                          onPressed: () => store.advance(t),
                          child: Text(switch (t.status) {
                            'nueva' => 'Empezar a preparar',
                            'preparando' => 'Marcar lista',
                            'lista' => 'Marcar entregada',
                            _ => t.status,
                          }),
                        ),
                      ),
                    ),
                  ]),
                );
              },
            );
          });
        },
      ),
    );
  }
}

// ======================= ADMINISTRADOR =======================
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}
class _AdminScreenState extends State<AdminScreen> {
  late final TextEditingController _rate = TextEditingController(text: store.rate.toStringAsFixed(2));
  @override
  void dispose() { _rate.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Administrador')),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) => ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Tasa de cambio (Bs por 1 USD)', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              const Text('1 USD =  ', style: TextStyle(fontWeight: FontWeight.bold)),
              Expanded(child: TextField(controller: _rate,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(suffixText: 'Bs', isDense: true, border: OutlineInputBorder()))),
              const SizedBox(width: 8),
              FilledButton(onPressed: () {
                final v = double.tryParse(_rate.text.replaceAll(',', '.'));
                if (v != null && v > 0) {
                  store.setRate(v);
                  FocusScope.of(context).unfocus();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tasa actualizada')));
                }
              }, child: const Text('Guardar')),
            ]),
          )),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: FilledButton.tonalIcon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductForm())),
              icon: const Icon(Icons.add), label: const Text('Nuevo producto'))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton.tonalIcon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
              icon: const Icon(Icons.history), label: const Text('Historial hoy'))),
          ]),
          const Divider(height: 28),
          const Text('Productos y precios (toca para editar)', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final c in Cat.values) ...[
            if (store.products.any((p) => p.cat == c)) ...[
              Padding(padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(catLabel(c), style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimary))),
              for (final p in store.products.where((p) => p.cat == c))
                Card(margin: const EdgeInsets.only(bottom: 6), child: ListTile(
                  leading: Text(p.emoji, style: const TextStyle(fontSize: 24)),
                  title: Text(p.name),
                  subtitle: Text('${dualPrice(p.price, p.cur)}  ·  base: ${p.cur.code}', style: const TextStyle(fontSize: 11.5)),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductForm(existing: p))),
                  trailing: Switch(value: p.available, onChanged: (_) => store.toggleProduct(p)),
                )),
            ],
          ],
        ]),
      ),
    );
  }
}

// ======================= FORMULARIO DE PRODUCTO =======================
class ProductForm extends StatefulWidget {
  final Product? existing;
  const ProductForm({super.key, this.existing});
  @override
  State<ProductForm> createState() => _ProductFormState();
}
class _ProductFormState extends State<ProductForm> {
  late TextEditingController _name;
  late TextEditingController _emoji;
  late TextEditingController _price;
  late TextEditingController _quita;
  late Cat _cat;
  late Currency _cur;
  late bool _available;
  late bool _useSizes;
  final List<List<TextEditingController>> _extras = []; // [nombre, precio]

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _emoji = TextEditingController(text: e?.emoji ?? '🍽️');
    _price = TextEditingController(text: e != null ? e.price.toStringAsFixed(2) : '');
    _quita = TextEditingController(text: e?.quita.join(', ') ?? '');
    _cat = e?.cat ?? Cat.hamburguesas;
    _cur = e?.cur ?? Currency.usd;
    _available = e?.available ?? true;
    _useSizes = e != null && e.sizes.isNotEmpty;
    if (e != null) {
      for (final ex in e.extras) {
        _extras.add([TextEditingController(text: ex.name), TextEditingController(text: ex.price.toStringAsFixed(2))]);
      }
    }
  }
  @override
  void dispose() {
    _name.dispose(); _emoji.dispose(); _price.dispose(); _quita.dispose();
    for (final row in _extras) { for (final c in row) { c.dispose(); } }
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final price = double.tryParse(_price.text.replaceAll(',', '.'));
    if (name.isEmpty || price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Revisa el nombre y el precio')));
      return;
    }
    final sizes = _useSizes ? [Sz('Pequena', -0.5), Sz('Mediana', 0), Sz('Grande', 0.8)] : <Sz>[];
    final extras = <Extra>[];
    for (var i = 0; i < _extras.length; i++) {
      final n = _extras[i][0].text.trim();
      final pr = double.tryParse(_extras[i][1].text.replaceAll(',', '.')) ?? 0;
      if (n.isNotEmpty) extras.add(Extra('x${i}_${DateTime.now().microsecondsSinceEpoch}', n, pr));
    }
    final quita = _quita.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final emoji = _emoji.text.trim().isEmpty ? '🍽️' : _emoji.text.trim();

    final e = widget.existing;
    if (e != null) {
      e.name = name; e.emoji = emoji; e.cat = _cat; e.price = price; e.cur = _cur;
      e.available = _available; e.sizes = sizes; e.extras = extras; e.quita = quita;
      store.updateProduct();
    } else {
      store.addProduct(Product(store.newProductId(), name, emoji, _cat, price, _cur,
          sizes: sizes, extras: extras, quita: quita, available: _available));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'Nuevo producto' : 'Editar producto'), actions: [
        if (widget.existing != null)
          IconButton(icon: const Icon(Icons.delete), onPressed: () {
            showDialog<void>(context: context, builder: (_) => AlertDialog(
              title: const Text('Eliminar producto'),
              content: Text('Eliminar "${widget.existing!.name}"?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                FilledButton(onPressed: () { store.deleteProduct(widget.existing!); Navigator.pop(context); Navigator.pop(context); },
                    child: const Text('Eliminar')),
              ],
            ));
          }),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        Row(children: [
          SizedBox(width: 90, child: TextField(controller: _emoji, textAlign: TextAlign.center,
              decoration: const InputDecoration(labelText: 'Icono', border: OutlineInputBorder()))),
          const SizedBox(width: 12),
          Expanded(child: DropdownButtonFormField<Cat>(
            value: _cat,
            decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
            items: [for (final c in Cat.values) DropdownMenuItem(value: c, child: Text(catLabel(c)))],
            onChanged: (v) => setState(() => _cat = v ?? Cat.otros),
          )),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Precio', border: OutlineInputBorder()))),
          const SizedBox(width: 12),
          SegmentedButton<Currency>(
            segments: const [ButtonSegment(value: Currency.usd, label: Text('USD')), ButtonSegment(value: Currency.ves, label: Text('Bs'))],
            selected: {_cur}, onSelectionChanged: (s) => setState(() => _cur = s.first),
          ),
        ]),
        const SizedBox(height: 6),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Disponible'),
            value: _available, onChanged: (v) => setState(() => _available = v)),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Usar tamanos (Pequena/Mediana/Grande)'),
            value: _useSizes, onChanged: (v) => setState(() => _useSizes = v)),
        const SizedBox(height: 6),
        TextField(controller: _quita, decoration: const InputDecoration(
            labelText: 'Ingredientes que se pueden quitar (separados por coma)',
            hintText: 'Cebolla, Tomate, Salsas', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        Row(children: [
          const Text('Extras', style: TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          TextButton.icon(onPressed: () => setState(() => _extras.add(
              [TextEditingController(), TextEditingController(text: '0')])),
              icon: const Icon(Icons.add), label: const Text('Agregar extra')),
        ]),
        for (var i = 0; i < _extras.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(flex: 3, child: TextField(controller: _extras[i][0],
                  decoration: const InputDecoration(labelText: 'Nombre extra', isDense: true, border: OutlineInputBorder()))),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: TextField(controller: _extras[i][1],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Precio', isDense: true, border: OutlineInputBorder()))),
              IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  onPressed: () => setState(() { _extras[i][0].dispose(); _extras[i][1].dispose(); _extras.removeAt(i); })),
            ]),
          ),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 50,
            child: FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('Guardar producto'))),
      ]),
    );
  }
}

// ======================= HISTORIAL DEL DIA =======================
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de hoy')),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final sales = store.todaySales;
          final units = store.unitsToday();
          final byMethod = store.byMethodToday();
          final sortedUnits = units.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          return ListView(padding: const EdgeInsets.all(16), children: [
            Card(color: kPrimary.withOpacity(0.08), child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Ventas de hoy', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(dualUsd(store.todayTotalUsd), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text('${sales.length} cuentas cobradas'),
              ]),
            )),
            const SizedBox(height: 12),
            const Text('Por medio de pago', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            if (byMethod.isEmpty) const Text('Sin ventas aun', style: TextStyle(color: Colors.grey))
            else for (final e in byMethod.entries)
              ListTile(dense: true, contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.payments), title: Text(e.key),
                  trailing: Text(dualUsd(e.value), style: const TextStyle(fontWeight: FontWeight.w600))),
            const Divider(height: 24),
            const Text('Unidades vendidas por producto', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            if (sortedUnits.isEmpty) const Text('Sin ventas aun', style: TextStyle(color: Colors.grey))
            else for (final e in sortedUnits)
              ListTile(dense: true, contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(radius: 15, backgroundColor: Colors.orange.shade50,
                      child: Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  title: Text(e.key)),
            const Divider(height: 24),
            const Text('Detalle de cuentas', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            if (sales.isEmpty) const Text('Sin ventas aun', style: TextStyle(color: Colors.grey))
            else for (final s in sales)
              Card(margin: const EdgeInsets.only(bottom: 6), child: ListTile(
                title: Text('${s.table != null ? 'Mesa ${s.table}' : 'Para llevar'}  ·  ${hhmm(s.at)}'),
                subtitle: Text(s.payments.map((p) => p.method).join(', ')),
                trailing: Text(usd(s.totalUsd), style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
          ]);
        },
      ),
    );
  }
}
