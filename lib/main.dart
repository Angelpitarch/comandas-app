// Comandas - Puesto de Comida (Etapa 2A: nube en tiempo real con Supabase)
// Un solo archivo. Datos compartidos entre dispositivos via Supabase.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ====== CREDENCIALES DE SUPABASE (la key publishable es segura para el cliente) ======
const kSupabaseUrl = 'https://tmjejukvdcfifajnmlca.supabase.co';
const kSupabaseKey = 'sb_publishable_yb-3O7QqTE9rgtUGJWSgdw_OXeHLgFg';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Supabase.initialize(url: kSupabaseUrl, anonKey: kSupabaseKey);
    store.init();
  } catch (e) {
    store.error = 'No se pudo conectar a la nube: $e';
  }
  runApp(const ComandasApp());
}

SupabaseClient get sb => Supabase.instance.client;

// ======================= MODELOS =======================
enum Currency { usd, ves }
extension CurCode on Currency { String get code => this == Currency.usd ? 'USD' : 'VES'; }
Currency curFrom(String s) => s == 'ves' ? Currency.ves : Currency.usd;
String curStr(Currency c) => c == Currency.usd ? 'usd' : 'ves';

enum Cat { hamburguesas, perros, papas, bebidas, combos, otros }
Cat catFrom(String s) => Cat.values.firstWhere((c) => c.name == s, orElse: () => Cat.otros);
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
  double stock;
  double minStock;
  bool trackStock;
  List<RecipeItem> recipe;
  List<ComboItem> comboItems;
  Product(this.id, this.name, this.emoji, this.cat, this.price, this.cur,
      {this.sizes = const [], this.extras = const [], this.quita = const [], this.available = true, this.stock = 0, this.minStock = 0, this.trackStock = false, this.recipe = const [], this.comboItems = const []});

  factory Product.fromRow(Map<String, dynamic> r) => Product(
        r['id'] as String,
        (r['name'] ?? '') as String,
        (r['emoji'] ?? '🍽️') as String,
        catFrom((r['category'] ?? 'otros') as String),
        ((r['price'] ?? 0) as num).toDouble(),
        curFrom((r['currency'] ?? 'usd') as String),
        available: (r['available'] ?? true) as bool,
        stock: ((r['stock'] ?? 0) as num).toDouble(),
        minStock: ((r['min_stock'] ?? 0) as num).toDouble(),
        trackStock: (r['track_stock'] ?? false) as bool,
        recipe: [for (final x in (r['recipe'] as List? ?? [])) RecipeItem((x['ingredient_id'] ?? '') as String, ((x['qty'] ?? 0) as num).toDouble())],
        comboItems: [for (final x in (r['combo_items'] as List? ?? [])) ComboItem((x['product_id'] ?? '') as String, ((x['qty'] ?? 0) as num).toDouble())],
        sizes: [for (final s in (r['sizes'] as List? ?? [])) Sz(s['name'] as String, (s['delta'] as num).toDouble())],
        extras: [for (final e in (r['extras'] as List? ?? [])) Extra((e['id'] ?? '') as String, e['name'] as String, ((e['price'] ?? 0) as num).toDouble())],
        quita: [for (final q in (r['quita'] as List? ?? [])) q.toString()],
      );

  Map<String, dynamic> toRow() => <String, dynamic>{
        'name': name,
        'emoji': emoji,
        'category': cat.name,
        'price': price,
        'currency': curStr(cur),
        'available': available,
        'stock': stock,
        'min_stock': minStock,
        'track_stock': trackStock,
        'recipe': [for (final r in recipe) <String, dynamic>{'ingredient_id': r.ingredientId, 'qty': r.qty}],
        'combo_items': [for (final c in comboItems) <String, dynamic>{'product_id': c.productId, 'qty': c.qty}],
        'sizes': [for (final s in sizes) <String, dynamic>{'name': s.name, 'delta': s.delta}],
        'extras': [for (final e in extras) <String, dynamic>{'id': e.id, 'name': e.name, 'price': e.price}],
        'quita': quita,
      };
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
}

class TableModel {
  final int number;
  final int cap;
  String status;
  String? waiter;
  DateTime? openedAt;
  TableModel(this.number, this.cap, {this.status = 'disponible', this.waiter, this.openedAt});
  factory TableModel.fromRow(Map<String, dynamic> r) => TableModel(
        (r['number'] as num).toInt(),
        ((r['capacity'] ?? 2) as num).toInt(),
        status: (r['status'] ?? 'disponible') as String,
        waiter: r['waiter'] as String?,
        openedAt: r['opened_at'] != null ? DateTime.tryParse(r['opened_at'] as String) : null,
      );
}

class TLine {
  final String name;
  final int qty;
  final String? size;
  final List<String> extras;
  final List<String> quita;
  final String? note;
  const TLine(this.name, this.qty, {this.size, this.extras = const [], this.quita = const [], this.note});
  factory TLine.fromJson(Map<String, dynamic> r) => TLine(
        (r['name'] ?? '') as String,
        ((r['qty'] ?? 1) as num).toInt(),
        size: r['size'] as String?,
        extras: [for (final e in (r['extras'] as List? ?? [])) e.toString()],
        quita: [for (final q in (r['quita'] as List? ?? [])) q.toString()],
        note: r['note'] as String?,
      );
}

class Ticket {
  final String id;
  final int number;
  final int? table;
  final String waiter;
  final DateTime sentAt;
  final String status;
  final List<TLine> lines;
  final String? note;
  final bool adicion;
  final bool reprinted;
  Ticket(this.id, this.number, this.table, this.waiter, this.sentAt, this.status, this.lines,
      {this.note, this.adicion = false, this.reprinted = false});
  factory Ticket.fromRow(Map<String, dynamic> r) => Ticket(
        r['id'] as String,
        ((r['number'] ?? 0) as num).toInt(),
        r['table_number'] != null ? (r['table_number'] as num).toInt() : null,
        (r['waiter'] ?? '') as String,
        DateTime.tryParse((r['sent_at'] ?? '') as String) ?? DateTime.now(),
        (r['status'] ?? 'nueva') as String,
        [for (final l in (r['lines'] as List? ?? [])) TLine.fromJson(Map<String, dynamic>.from(l as Map))],
        note: r['note'] as String?,
        adicion: (r['adicion'] ?? false) as bool,
        reprinted: (r['reprinted'] ?? false) as bool,
      );
}

class AccLine {
  final String id;
  final int table;
  final String name;
  final int qty;
  final String? size;
  final List<String> extras;
  final List<String> quita;
  final String? note;
  final double unitUsd;
  AccLine(this.id, this.table, this.name, this.qty, this.size, this.extras, this.quita, this.note, this.unitUsd);
  factory AccLine.fromRow(Map<String, dynamic> r) => AccLine(
        r['id'] as String,
        (r['table_number'] as num).toInt(),
        (r['product_name'] ?? '') as String,
        ((r['qty'] ?? 1) as num).toInt(),
        r['size'] as String?,
        [for (final e in (r['extras'] as List? ?? [])) e.toString()],
        [for (final q in (r['quita'] as List? ?? [])) q.toString()],
        r['note'] as String?,
        ((r['unit_usd'] ?? 0) as num).toDouble(),
      );
  double get lineUsd => unitUsd * qty;
}

class Payment {
  final String method;
  final double amountUsd;
  final String? reference;
  Payment(this.method, this.amountUsd, {this.reference});
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
  factory Sale.fromRow(Map<String, dynamic> r) => Sale(
        r['table_number'] != null ? (r['table_number'] as num).toInt() : null,
        DateTime.tryParse((r['at'] ?? '') as String) ?? DateTime.now(),
        [for (final l in (r['lines'] as List? ?? [])) SaleLine((l['name'] ?? '') as String, ((l['qty'] ?? 0) as num).toInt(), ((l['lineUsd'] ?? 0) as num).toDouble())],
        ((r['total_usd'] ?? 0) as num).toDouble(),
        [for (final p in (r['payments'] as List? ?? [])) Payment((p['method'] ?? '') as String, ((p['amountUsd'] ?? 0) as num).toDouble(), reference: p['reference'] as String?)],
      );
}

// ======================= STORE (conectado a Supabase) =======================
class Store extends ChangeNotifier {
  String? error;
  bool connected = false;
  double rate = 36.5;
  List<Product> products = [];
  List<TableModel> tables = [];
  List<Ticket> tickets = [];
  Map<int, List<AccLine>> accounts = {};
  List<Sale> sales = [];
  List<Ingredient> ingredients = [];
  final List<String> methods = ['Efectivo Bs', 'Efectivo USD', 'Pago movil', 'Tarjeta'];
  final Map<String, List<CartItem>> _carts = {};
  String currentUser = '';

  void init() {
    sb.from('app_config').stream(primaryKey: ['id']).listen((rows) {
      if (rows.isNotEmpty) { rate = ((rows.first['rate'] ?? 36.5) as num).toDouble(); connected = true; notifyListeners(); }
    }, onError: _onErr);
    sb.from('products').stream(primaryKey: ['id']).order('name').listen((rows) {
      products = rows.map((r) => Product.fromRow(r)).toList();
      connected = true; notifyListeners();
    }, onError: _onErr);
    sb.from('dining_tables').stream(primaryKey: ['number']).order('number').listen((rows) {
      tables = rows.map((r) => TableModel.fromRow(r)).toList(); notifyListeners();
    }, onError: _onErr);
    sb.from('tickets').stream(primaryKey: ['id']).order('sent_at').listen((rows) {
      tickets = rows.map((r) => Ticket.fromRow(r)).toList(); notifyListeners();
    }, onError: _onErr);
    sb.from('account_items').stream(primaryKey: ['id']).listen((rows) {
      final m = <int, List<AccLine>>{};
      for (final r in rows) { final a = AccLine.fromRow(r); (m[a.table] ??= []).add(a); }
      accounts = m; notifyListeners();
    }, onError: _onErr);
    sb.from('sales').stream(primaryKey: ['id']).order('at', ascending: false).listen((rows) {
      sales = rows.map((r) => Sale.fromRow(r)).toList(); notifyListeners();
    }, onError: _onErr);
    sb.from('ingredients').stream(primaryKey: ['id']).order('name').listen((rows) {
      ingredients = rows.map((r) => Ingredient.fromRow(r)).toList(); notifyListeners();
    }, onError: _onErr);
  }

  void _onErr(Object e) { error = 'Error de conexion: $e'; notifyListeners(); }
  void clearError() { error = null; notifyListeners(); }

  List<CartItem> cart(String key) => _carts.putIfAbsent(key, () => []);
  void touch() => notifyListeners();

  double toUsd(double amt, Currency c) => c == Currency.usd ? amt : amt / rate;
  double toVes(double amt, Currency c) => c == Currency.ves ? amt : amt * rate;
  double lineUsd(CartItem it) => toUsd(it.unit(), it.p.cur) * it.qty;
  double cartTotalUsd(String key) => cart(key).fold(0.0, (s, it) => s + lineUsd(it));
  int cartCount(String key) => cart(key).fold(0, (s, it) => s + it.qty);
  List<AccLine> account(int n) => accounts[n] ?? const [];
  double accountTotalUsd(int n) => account(n).fold(0.0, (s, a) => s + a.lineUsd);
  List<Ticket> ticketsOf(int n) => tickets.where((x) => x.table == n && x.status != 'anulada').toList();
  List<Product> get lowStock => products.where((p) => p.trackStock && p.stock <= p.minStock).toList();
  List<Ingredient> get lowIngredients => ingredients.where((i) => i.low).toList();
  Future<void> addIngredient(Ingredient i) async { try { await sb.from('ingredients').insert(i.toRow()); } catch (e) { _onErr(e); } }
  Future<void> updateIngredient(Ingredient i) async { try { await sb.from('ingredients').update(i.toRow()).eq('id', i.id); } catch (e) { _onErr(e); } }
  Future<void> deleteIngredient(Ingredient i) async { try { await sb.from('ingredients').delete().eq('id', i.id); } catch (e) { _onErr(e); } }
  Future<void> freeTable(int n) async {
    try { await sb.from('dining_tables').update(<String, dynamic>{'status': 'disponible', 'waiter': null, 'opened_at': null}).eq('number', n); } catch (e) { _onErr(e); }
  }
  Future<void> transferTable(int from, int to) async {
    try {
      await sb.from('account_items').update(<String, dynamic>{'table_number': to}).eq('table_number', from);
      await sb.from('tickets').update(<String, dynamic>{'table_number': to}).eq('table_number', from).neq('status', 'anulada');
      await sb.from('dining_tables').update(<String, dynamic>{'status': 'ocupada', 'waiter': currentUser}).eq('number', to);
      await sb.from('dining_tables').update(<String, dynamic>{'status': 'disponible', 'waiter': null, 'opened_at': null}).eq('number', from);
    } catch (e) { _onErr(e); }
  }
  Product? productById(String id) { for (final p in products) { if (p.id == id) return p; } return null; }
  Ingredient? ingredientById(String id) { for (final i in ingredients) { if (i.id == id) return i; } return null; }
  int maxMakeable(Product p) {
    const big = 1000000000;
    if (p.comboItems.isNotEmpty) {
      var m = big;
      for (final c in p.comboItems) {
        final cp = productById(c.productId);
        if (cp == null || c.qty <= 0) continue;
        final cm = maxMakeable(cp);
        if (cm < 0) continue;
        final canDo = (cm / c.qty).floor();
        if (canDo < m) m = canDo;
      }
      return m == big ? -1 : m;
    }
    if (p.recipe.isNotEmpty) {
      var m = big;
      for (final r in p.recipe) {
        final ing = ingredientById(r.ingredientId);
        if (ing == null || r.qty <= 0) continue;
        final canDo = (ing.stock / r.qty).floor();
        if (canDo < m) m = canDo;
      }
      return m == big ? -1 : m;
    }
    return -1;
  }
  Future<void> _consume(Product p, double q) async {
    if (p.comboItems.isNotEmpty) {
      for (final c in p.comboItems) {
        final cp = productById(c.productId);
        if (cp != null) await _consume(cp, c.qty * q);
      }
      return;
    }
    if (p.recipe.isNotEmpty) {
      for (final r in p.recipe) {
        await sb.rpc('deduct_ingredient', params: <String, dynamic>{'i_id': r.ingredientId, 'i_qty': r.qty * q});
      }
      return;
    }
    if (p.trackStock) {
      await sb.rpc('deduct_stock', params: <String, dynamic>{'p_id': p.id, 'p_qty': q});
    }
  }

  int _nextTicketNumber() {
    var m = 0;
    for (final t in tickets) { if (t.number > m) m = t.number; }
    return m + 1;
  }

  String tableStatus(int n) {
    final t = tables.where((e) => e.number == n).toList();
    final st = t.isEmpty ? 'disponible' : t.first.status;
    if (st == 'pagada') return 'pagada';
    final tk = tickets.where((x) => x.table == n && x.status != 'anulada' && x.status != 'entregada').toList();
    if (tk.any((x) => x.status == 'lista')) return 'listo';
    if (tk.isNotEmpty) return 'cocina';
    if (account(n).isNotEmpty) return 'servido';
    return 'disponible';
  }

  Future<void> setRate(double r) async {
    try { await sb.from('app_config').update(<String, dynamic>{'rate': r, 'updated_at': DateTime.now().toIso8601String()}).eq('id', 1); }
    catch (e) { _onErr(e); }
  }
  Future<void> toggleProduct(Product p) async {
    try { await sb.from('products').update(<String, dynamic>{'available': !p.available}).eq('id', p.id); }
    catch (e) { _onErr(e); }
  }
  Future<void> addProduct(Product p) async {
    try { await sb.from('products').insert(p.toRow()); } catch (e) { _onErr(e); }
  }
  Future<void> updateProduct(Product p) async {
    try { await sb.from('products').update(p.toRow()).eq('id', p.id); } catch (e) { _onErr(e); }
  }
  Future<void> deleteProduct(Product p) async {
    try { await sb.from('products').delete().eq('id', p.id); } catch (e) { _onErr(e); }
  }
  Future<void> openTable(int n) async {
    try {
      final t = tables.firstWhere((e) => e.number == n);
      if (t.status == 'disponible') {
        await sb.from('dining_tables').update(<String, dynamic>{
          'status': 'ocupada', 'waiter': currentUser, 'opened_at': DateTime.now().toIso8601String(),
        }).eq('number', n);
      }
    } catch (e) { _onErr(e); }
  }

  Future<int?> send(String key, {int? table, String? note, bool keepCart = false}) async {
    final items = cart(key);
    if (items.isEmpty) return null;
    final number = _nextTicketNumber();
    final adicion = table != null && tickets.any((t) => t.table == table && t.status != 'anulada');
    List<String> exNames(CartItem it) => [for (final e in it.p.extras) if (it.extras.contains(e.id)) e.name];
    final lines = [for (final it in items) <String, dynamic>{
      'name': it.p.name, 'qty': it.qty, 'size': it.size?.name, 'extras': exNames(it), 'quita': it.quita.toList(), 'note': it.note,
    }];
    try {
      await sb.from('tickets').insert(<String, dynamic>{
        'number': number, 'table_number': table, 'waiter': currentUser,
        'status': 'nueva', 'adicion': adicion, 'note': note, 'lines': lines,
      });
      if (table != null) {
        final accRows = [for (final it in items) <String, dynamic>{
          'table_number': table, 'product_name': it.p.name, 'qty': it.qty, 'size': it.size?.name,
          'extras': exNames(it), 'quita': it.quita.toList(), 'note': it.note, 'unit_usd': toUsd(it.unit(), it.p.cur),
        }];
        await sb.from('account_items').insert(accRows);
        await sb.from('dining_tables').update(<String, dynamic>{'status': 'ocupada', 'waiter': currentUser, 'opened_at': DateTime.now().toIso8601String()}).eq('number', table);
      }
      for (final it in items) {
        await _consume(it.p, it.qty.toDouble());
      }
      if (!keepCart) items.clear();
      notifyListeners();
      return number;
    } catch (e) { _onErr(e); return null; }
  }

  Future<void> advance(Ticket t) async {
    final next = switch (t.status) { 'nueva' => 'preparando', 'preparando' => 'lista', 'lista' => 'entregada', _ => t.status };
    try { await sb.from('tickets').update(<String, dynamic>{'status': next}).eq('id', t.id); } catch (e) { _onErr(e); }
  }
  Future<void> cancelTicket(Ticket t) async {
    try { await sb.from('tickets').update(<String, dynamic>{'status': 'anulada'}).eq('id', t.id); } catch (e) { _onErr(e); }
  }
  Future<void> reprint(Ticket t) async {
    try { await sb.from('tickets').update(<String, dynamic>{'reprinted': true}).eq('id', t.id); } catch (e) { _onErr(e); }
  }

  Future<bool> pay(List<Payment> payments, {int? table, String? cartKey}) async {
    try {
      List<Map<String, dynamic>> saleLines;
      double total;
      if (table != null) {
        final acc = account(table);
        if (acc.isEmpty) return false;
        saleLines = [for (final a in acc) <String, dynamic>{'name': a.name, 'qty': a.qty, 'lineUsd': a.lineUsd}];
        total = acc.fold(0.0, (s, a) => s + a.lineUsd);
      } else {
        final items = cart(cartKey ?? '');
        if (items.isEmpty) return false;
        saleLines = [for (final it in items) <String, dynamic>{'name': it.p.name, 'qty': it.qty, 'lineUsd': lineUsd(it)}];
        total = items.fold(0.0, (s, it) => s + lineUsd(it));
      }
      await sb.from('sales').insert(<String, dynamic>{
        'table_number': table, 'total_usd': total, 'lines': saleLines,
        'payments': [for (final p in payments) <String, dynamic>{'method': p.method, 'amountUsd': p.amountUsd, 'reference': p.reference}],
      });
      if (table != null) {
        await sb.from('account_items').delete().eq('table_number', table);
        await sb.from('dining_tables').update(<String, dynamic>{'status': 'pagada'}).eq('number', table);
        await sb.from('tickets').update(<String, dynamic>{'status': 'entregada'}).eq('table_number', table).neq('status', 'anulada');
      } else {
        cart(cartKey ?? '').clear();
      }
      notifyListeners();
      return true;
    } catch (e) { _onErr(e); return false; }
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

// ======================= FORMATO =======================
String _grp(String s) {
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) { if (i > 0 && (s.length - i) % 3 == 0) b.write('.'); b.write(s[i]); }
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
      builder: (context, child) => AnimatedBuilder(
        animation: store,
        builder: (_, __) => Stack(children: [
          Positioned.fill(child: child ?? const SizedBox()),
          if (store.error != null)
            Positioned(left: 0, right: 0, bottom: 0, child: SafeArea(
              child: Material(color: Colors.red.shade700, child: InkWell(
                onTap: store.clearError,
                child: Padding(padding: const EdgeInsets.all(10), child: Row(children: [
                  const Icon(Icons.wifi_off, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(store.error!, style: const TextStyle(color: Colors.white, fontSize: 12))),
                  const Icon(Icons.close, color: Colors.white, size: 18),
                ])),
              )),
            )),
        ]),
      ),
    );
  }
}

Color statusColor(String s) => switch (s) {
      'disponible' => const Color(0xFF66BB6A),
      'ocupada' => const Color(0xFFFFA726),
      'cocina' => const Color(0xFF42A5F5),
      'listo' => const Color(0xFF26C6DA),
      'servido' => const Color(0xFFAB47BC),
      'pagada' => const Color(0xFF8D6E63),
      _ => const Color(0xFF90A4AE),
    };
String statusLabel(String s) => switch (s) {
      'disponible' => 'Disponible',
      'ocupada' => 'Ocupada',
      'cocina' => 'En cocina',
      'listo' => 'Pedido listo',
      'servido' => 'Servido',
      'pagada' => 'Pagada - liberar',
      _ => s,
    };

Widget lowStockCard() {
  final low = store.lowStock;
  return Card(color: Colors.red.shade50, child: Padding(padding: const EdgeInsets.all(12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: const [Icon(Icons.warning_amber, color: Colors.red), SizedBox(width: 8),
        Text('Inventario bajo', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red))]),
      const SizedBox(height: 6),
      for (final p in low)
        Text('- ' + p.name + ': ' + (p.stock <= 0 ? 'AGOTADO' : 'quedan ' + p.stock.toStringAsFixed(0)) + ' (min ' + p.minStock.toStringAsFixed(0) + ')',
            style: const TextStyle(fontSize: 12.5)),
    ])));
}

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
      if (name == null) { setState(() { _err = 'PIN incorrecto'; _pin = ''; }); }
      else { store.currentUser = name; Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())); setState(() => _pin = ''); }
    }
  }
  void _back() { if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1)); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: Center(child: SingleChildScrollView(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lunch_dining, size: 72, color: kPrimary),
          const SizedBox(height: 8),
          const Text('Comandas', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
          AnimatedBuilder(animation: store, builder: (_, __) => Text(
            store.connected ? 'Conectado a la nube ✓' : 'Conectando...',
            style: TextStyle(fontSize: 12, color: store.connected ? Colors.green : Colors.grey))),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(4, (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 8), width: 18, height: 18,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: i < _pin.length ? kPrimary : Colors.transparent, border: Border.all(color: kPrimary, width: 2))))),
          SizedBox(height: 24, child: Text(_err ?? '', style: const TextStyle(color: Colors.red))),
          _keypad(),
          const SizedBox(height: 16),
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(12)),
              child: const Text('PIN de prueba:\nAdmin 1111 · Mesero 2222 · Cocina 3333', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5))),
        ])),
      )))),
    );
  }
  Widget _k(String label, {VoidCallback? action, Widget? child}) => Padding(padding: const EdgeInsets.all(6),
      child: SizedBox(width: 72, height: 62, child: FilledButton.tonal(onPressed: action ?? () => _tap(label),
          child: child ?? Text(label, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)))));
  Widget _keypad() => Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [_k('1'), _k('2'), _k('3')]),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [_k('4'), _k('5'), _k('6')]),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [_k('7'), _k('8'), _k('9')]),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [const SizedBox(width: 84), _k('0'),
            _k('', action: _back, child: const Icon(Icons.backspace_outlined))]),
      ]);
}

// ======================= SELECTOR DE PERFIL =======================
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    Widget card(IconData ic, String t, Color c, Widget dest) => SizedBox(width: 200, height: 170,
        child: Card(child: InkWell(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => dest)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              CircleAvatar(radius: 38, backgroundColor: c.withOpacity(0.15), child: Icon(ic, size: 40, color: c)),
              const SizedBox(height: 14),
              Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ]))));
    return Scaffold(
      appBar: AppBar(title: const Text('Selecciona un perfil')),
      body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(20),
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
        ]))),
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
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderScreen(cartKey: 'llevar', table: null))),
        icon: const Icon(Icons.takeout_dining), label: const Text('Para llevar'),
      ),
      body: AnimatedBuilder(animation: store, builder: (context, _) {
        if (store.tables.isEmpty) return const Center(child: CircularProgressIndicator());
        return LayoutBuilder(builder: (context, cns) {
          final cols = (cns.maxWidth / 180).floor().clamp(2, 6).toInt();
          return GridView.builder(
            padding: const EdgeInsets.all(14),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.0),
            itemCount: store.tables.length,
            itemBuilder: (context, i) {
              final t = store.tables[i];
              final s = store.tableStatus(t.number);
              final total = store.accountTotalUsd(t.number);
              final c = statusColor(s);
              return Card(child: InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TableDetailScreen(table: t.number))),
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
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: c.withOpacity(0.18), borderRadius: BorderRadius.circular(20)),
                        child: Text(statusLabel(s), style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 11.5))),
                    const Spacer(),
                    if (t.waiter != null) Text(t.waiter!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5)),
                    if (total > 0) Text('Cuenta: ${usd(total)}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ));
            },
          );
        });
      }),
    );
  }
}

// ======================= DETALLE DE MESA =======================
class TableDetailScreen extends StatelessWidget {
  final int table;
  const TableDetailScreen({super.key, required this.table});

  void _cambiarMesa(BuildContext context) {
    final destinos = store.tables.where((t) => t.number != table && store.tableStatus(t.number) == 'disponible').toList();
    showDialog<void>(context: context, builder: (dctx) => AlertDialog(
      title: const Text('Cambiar de mesa'),
      content: destinos.isEmpty
          ? const Text('No hay mesas disponibles.')
          : SizedBox(width: double.maxFinite, child: ListView(shrinkWrap: true, children: [
              for (final t in destinos)
                ListTile(leading: const Icon(Icons.table_bar), title: Text('Mesa ${t.number}'),
                  onTap: () async {
                    Navigator.pop(dctx);
                    await store.transferTable(table, t.number);
                    if (context.mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Comanda movida a Mesa ${t.number}'))); }
                  }),
            ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Cancelar'))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Mesa $table'), actions: [
        IconButton(tooltip: 'Cambiar de mesa', icon: const Icon(Icons.swap_horiz), onPressed: () => _cambiarMesa(context)),
      ]),
      body: AnimatedBuilder(animation: store, builder: (context, _) {
        final acc = store.account(table);
        final tk = store.ticketsOf(table);
        final total = store.accountTotalUsd(table);
        return Column(children: [
          Expanded(child: ListView(padding: const EdgeInsets.all(14), children: [
            if (tk.isNotEmpty) ...[
              const Text('Estado en cocina', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              for (final k in tk)
                Card(margin: const EdgeInsets.only(bottom: 6), child: ListTile(dense: true,
                  leading: CircleAvatar(backgroundColor: _kColor(k.status).withOpacity(0.18), child: Icon(_kIcon(k.status), color: _kColor(k.status), size: 20)),
                  title: Text('Comanda #${k.number.toString().padLeft(6, '0')}${k.adicion ? '  (ADICION)' : ''}'),
                  subtitle: Text('${k.lines.length} productos · enviada ${hhmm(k.sentAt)}'),
                  trailing: Text(_kLabel(k.status), style: TextStyle(color: _kColor(k.status), fontWeight: FontWeight.w600)))),
              const SizedBox(height: 12),
            ],
            const Text('Lo pedido en esta mesa', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            if (acc.isEmpty)
              const Padding(padding: EdgeInsets.all(12), child: Text('Aun no hay productos. Toca "Agregar".', style: TextStyle(color: Colors.grey)))
            else
              for (final a in acc)
                Card(margin: const EdgeInsets.only(bottom: 6), child: ListTile(dense: true,
                  leading: CircleAvatar(radius: 14, backgroundColor: Colors.orange.shade50, child: Text('${a.qty}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  title: Text(a.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  subtitle: Text([if (a.size != null) a.size!, ...a.extras.map((e) => '+$e'), ...a.quita.map((q) => 'Sin $q'), if (a.note != null) 'Nota: ${a.note}'].join(' · '), style: const TextStyle(fontSize: 11)),
                  trailing: Text(usd(a.lineUsd), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)))),
          ])),
          Material(elevation: 8, child: SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [const Text('Total mesa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const Spacer(), Text(dualUsd(total), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))]),
              const SizedBox(height: 10),
              if (store.tableStatus(table) == 'pagada') ...[
                const Text('Cuenta PAGADA. Libera la mesa cuando el cliente se retire.', style: TextStyle(fontSize: 12.5, color: Color(0xFF6D4C41))),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, height: 50, child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF66BB6A)),
                  onPressed: () async { await store.freeTable(table); if (context.mounted) Navigator.pop(context); },
                  icon: const Icon(Icons.check_circle), label: const Text('Liberar mesa'))),
              ] else ...[
                Row(children: [
                  Expanded(child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderScreen(cartKey: 'mesa-$table', table: table))),
                    icon: const Icon(Icons.add), label: const Text('Agregar'))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton.icon(
                    onPressed: acc.isEmpty ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiptScreen(table: table))),
                    icon: const Icon(Icons.receipt_long), label: const Text('Comprobante'))),
                ]),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, height: 50, child: FilledButton.icon(
                  onPressed: acc.isEmpty ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentScreen(table: table))),
                  icon: const Icon(Icons.point_of_sale), label: const Text('Cobrar'))),
              ],
            ]))))
        ]);
      }),
    );
  }
}

Color _kColor(String s) => switch (s) {
      'nueva' => const Color(0xFF42A5F5), 'preparando' => const Color(0xFFFFA726),
      'lista' => const Color(0xFF26C6DA), 'entregada' => const Color(0xFF66BB6A), _ => Colors.grey };
IconData _kIcon(String s) => switch (s) {
      'nueva' => Icons.fiber_new, 'preparando' => Icons.outdoor_grill,
      'lista' => Icons.room_service, 'entregada' => Icons.check_circle, _ => Icons.cancel };
String _kLabel(String s) => switch (s) {
      'nueva' => 'Recibida', 'preparando' => 'Preparando', 'lista' => 'Lista', 'entregada' => 'Entregada', _ => s };

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
    final item = await showModalBottomSheet<CartItem>(context: context, isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => ItemEditor(product: p, existing: existing));
    if (item != null && existing == null) { store.cart(widget.cartKey).add(item); store.touch(); }
    else if (item != null) { store.touch(); }
  }

  Future<void> _send() async {
    if (_sending || store.cart(widget.cartKey).isEmpty) return;
    setState(() => _sending = true);
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    final number = await store.send(widget.cartKey, table: widget.table, note: note, keepCart: widget.table == null);
    if (!mounted) return;
    setState(() { _sending = false; if (widget.table == null) _sentTakeaway = true; });
    _noteCtrl.clear();
    if (number == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo enviar. Revisa la conexion.')));
      return;
    }
    if (widget.table != null) {
      await showDialog<void>(context: context, builder: (_) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: Text('Comanda #${number.toString().padLeft(6, '0')}'),
        content: const Text('Comanda enviada a cocina.'),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido'))]));
      if (mounted) Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enviado a cocina')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.table != null ? 'Agregar - Mesa ${widget.table}' : 'Para llevar';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: AnimatedBuilder(animation: store, builder: (context, _) {
        final items = store.cart(widget.cartKey);
        final total = store.cartTotalUsd(widget.cartKey);
        final prods = store.products.where((p) => p.cat == _cat).toList();
        return Column(children: [
          SizedBox(height: 52, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 10), children: [
            for (final c in Cat.values) Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Center(child: ChoiceChip(label: Text(catLabel(c)), selected: c == _cat, onSelected: (_) => setState(() => _cat = c)))),
          ])),
          Expanded(child: prods.isEmpty
              ? const Center(child: Text('Sin productos en esta categoria', style: TextStyle(color: Colors.grey)))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 190, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.9),
                  itemCount: prods.length,
                  itemBuilder: (context, i) {
                    final p = prods[i];
                    return Card(child: InkWell(onTap: p.available ? () => _addOrEdit(p) : null,
                      child: Opacity(opacity: p.available ? 1 : 0.4, child: Padding(padding: const EdgeInsets.all(8),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Center(child: Text(p.emoji, style: const TextStyle(fontSize: 38))),
                          const Spacer(),
                          Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.1, fontSize: 13)),
                          const SizedBox(height: 3),
                          Text(dualPrice(p.price, p.cur), style: const TextStyle(fontSize: 10.5)),
                          if (p.trackStock) Text('Quedan ' + p.stock.toStringAsFixed(0), style: TextStyle(fontSize: 10, color: p.stock <= p.minStock ? Colors.red : Colors.grey[600])),
                          if (!p.available) const Text('No disponible', style: TextStyle(color: Colors.red, fontSize: 10)),
                        ])))));
                  })),
          Material(elevation: 8, child: SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (items.isNotEmpty)
                ConstrainedBox(constraints: const BoxConstraints(maxHeight: 150), child: ListView(shrinkWrap: true, children: [
                  for (final it in items)
                    Dismissible(key: ValueKey(it), direction: DismissDirection.endToStart,
                      background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 16), child: const Icon(Icons.delete, color: Colors.white)),
                      onDismissed: (_) { items.remove(it); store.touch(); },
                      child: ListTile(dense: true,
                        leading: CircleAvatar(radius: 14, backgroundColor: Colors.orange.shade50, child: Text('${it.qty}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        title: Text(it.p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text([if (it.size != null) it.size!.name, ...it.p.extras.where((e) => it.extras.contains(e.id)).map((e) => '+${e.name}'), ...it.quita.map((q) => 'Sin $q'), if (it.note != null) 'Nota: ${it.note}'].join(' · '), style: const TextStyle(fontSize: 11)),
                        trailing: Text(usd(store.lineUsd(it)), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        onTap: () => _addOrEdit(it.p, existing: it))),
                ]))
              else const Padding(padding: EdgeInsets.all(8), child: Text('Agrega productos del menu', style: TextStyle(color: Colors.grey))),
              TextField(controller: _noteCtrl, decoration: const InputDecoration(isDense: true, labelText: 'Observacion general', hintText: 'Ej: entregar bebidas primero', border: OutlineInputBorder(), prefixIcon: Icon(Icons.sticky_note_2_outlined))),
              const SizedBox(height: 10),
              Row(children: [const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const Spacer(), Text(dualUsd(total), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))]),
              const SizedBox(height: 8),
              if (widget.table != null)
                SizedBox(width: double.infinity, height: 50, child: FilledButton.icon(
                  onPressed: (items.isEmpty || _sending) ? null : _send,
                  icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send),
                  label: Text(_sending ? 'Enviando...' : 'Enviar a cocina')))
              else Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: (items.isEmpty || _sending) ? null : _send, icon: const Icon(Icons.send), label: Text(_sentTakeaway ? 'Enviar de nuevo' : 'Enviar a cocina'))),
                const SizedBox(width: 8),
                Expanded(child: FilledButton.icon(onPressed: items.isEmpty ? null : () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentScreen(table: null, cartKey: widget.cartKey)));
                  if (mounted && store.cart(widget.cartKey).isEmpty) Navigator.pop(context);
                }, icon: const Icon(Icons.point_of_sale), label: const Text('Cobrar'))),
              ]),
            ]))))
        ]);
      }),
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
    if (e != null) { e.size = _size; e.qty = _qty; e.extras = _extras; e.quita = _quita; e.note = note; Navigator.pop(context, e); }
    else { Navigator.pop(context, CartItem(widget.product, qty: _qty, size: _size, extras: _extras, quita: _quita, note: note)); }
  }
  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(expand: false, initialChildSize: 0.75, maxChildSize: 0.95, minChildSize: 0.5,
        builder: (context, scroll) => Column(children: [
          const SizedBox(height: 10),
          Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(4))),
          Expanded(child: ListView(controller: scroll, padding: const EdgeInsets.all(20), children: [
            Row(children: [Text(p.emoji, style: const TextStyle(fontSize: 30)), const SizedBox(width: 10), Expanded(child: Text(p.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)))]),
            const SizedBox(height: 4),
            Text(dualPrice(_unit, p.cur), style: const TextStyle(fontWeight: FontWeight.w600)),
            const Divider(height: 26),
            if (p.sizes.isNotEmpty) ...[
              const Text('Tamano', style: TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 8),
              Wrap(spacing: 8, children: [for (final s in p.sizes) ChoiceChip(label: Text(s.name), selected: _size?.name == s.name, onSelected: (_) => setState(() => _size = s))]),
              const SizedBox(height: 16),
            ],
            if (p.extras.isNotEmpty) ...[
              const Text('Extras', style: TextStyle(fontWeight: FontWeight.w600)),
              for (final ex in p.extras) CheckboxListTile(contentPadding: EdgeInsets.zero, dense: true,
                  value: _extras.contains(ex.id), title: Text(ex.name), secondary: Text('+ ${usd(ex.price)}'),
                  onChanged: (v) => setState(() => v == true ? _extras.add(ex.id) : _extras.remove(ex.id))),
              const SizedBox(height: 12),
            ],
            if (p.quita.isNotEmpty) ...[
              const Text('Quitar ingredientes', style: TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 8),
              Wrap(spacing: 8, children: [for (final ing in p.quita) FilterChip(label: Text('Sin $ing'), selected: _quita.contains(ing), onSelected: (v) => setState(() => v ? _quita.add(ing) : _quita.remove(ing)))]),
              const SizedBox(height: 16),
            ],
            TextField(controller: _note, maxLines: 2, decoration: const InputDecoration(labelText: 'Observacion del producto', border: OutlineInputBorder())),
          ])),
          SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), child: Row(children: [
            Container(decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.remove), onPressed: _qty > 1 ? () => setState(() => _qty--) : null),
                Text('$_qty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.add), onPressed: () => setState(() => _qty++)),
              ])),
            const SizedBox(width: 12),
            Expanded(child: FilledButton.icon(onPressed: _confirm, icon: const Icon(Icons.add_shopping_cart), label: Text(widget.existing == null ? 'Agregar' : 'Guardar'))),
          ]))),
        ])));
  }
}

// ======================= COBRO / PAGO =======================
class _Line {
  final String name;
  final int qty;
  final double lineUsd;
  _Line(this.name, this.qty, this.lineUsd);
}

class PaymentScreen extends StatefulWidget {
  final int? table;
  final String? cartKey;
  const PaymentScreen({super.key, this.table, this.cartKey});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}
class _PaymentScreenState extends State<PaymentScreen> {
  int _mode = 0;
  int _persons = 2;
  bool _paying = false;
  final Map<int, int> _assign = {};
  final Map<int, String> _method = {};
  final Map<int, TextEditingController> _refCtrls = {};
  TextEditingController _refFor(int i) => _refCtrls.putIfAbsent(i, () => TextEditingController());
  @override
  void dispose() { for (final c in _refCtrls.values) { c.dispose(); } super.dispose(); }

  List<_Line> get _lines => widget.table != null
      ? store.account(widget.table!).map((a) => _Line(a.name, a.qty, a.lineUsd)).toList()
      : store.cart(widget.cartKey ?? '').map((it) => _Line(it.p.name, it.qty, store.lineUsd(it))).toList();
  double get _totalUsd => _lines.fold(0.0, (s, l) => s + l.lineUsd);

  List<double> _parts() {
    final lines = _lines;
    if (_mode == 0) return [_totalUsd];
    if (_mode == 1) return List.filled(_persons, _totalUsd / _persons);
    final res = List.filled(_persons, 0.0);
    for (var i = 0; i < lines.length; i++) {
      final person = (_assign[i] ?? 0).clamp(0, _persons - 1).toInt();
      res[person] += lines[i].lineUsd;
    }
    return res;
  }

  Future<void> _confirm() async {
    if (_paying) return;
    final parts = _parts();
    final payments = <Payment>[];
    for (var i = 0; i < parts.length; i++) {
      if (parts[i] <= 0) continue;
      payments.add(Payment(_method[i] ?? store.methods.first, parts[i], reference: _refFor(i).text.trim().isEmpty ? null : _refFor(i).text.trim()));
    }
    if (payments.isEmpty) return;
    setState(() => _paying = true);
    final nav = Navigator.of(context);
    final ok = await store.pay(payments, table: widget.table, cartKey: widget.cartKey);
    if (!mounted) return;
    setState(() => _paying = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo cobrar. Revisa la conexion.')));
      return;
    }
    await showDialog<void>(context: context, builder: (dctx) => AlertDialog(
      icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
      title: const Text('Cobro registrado'),
      content: Text(widget.table != null ? 'Mesa ${widget.table}: cuenta PAGADA.\nLibera la mesa cuando el cliente se retire.' : 'Pedido para llevar cobrado.'),
      actions: [FilledButton(onPressed: () => Navigator.pop(dctx), child: const Text('Listo'))]));
    if (!mounted) return;
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.table != null ? 'Cobrar - Mesa ${widget.table}' : 'Cobrar - Para llevar')),
      body: AnimatedBuilder(animation: store, builder: (context, _) {
        final lines = _lines;
        final parts = _parts();
        return Column(children: [
          Expanded(child: ListView(padding: const EdgeInsets.all(14), children: [
            Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
              const Text('Total a cobrar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(), Text(dualUsd(_totalUsd), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ]))),
            const SizedBox(height: 6),
            const Text('Dividir la cuenta', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            SegmentedButton<int>(
              segments: const [ButtonSegment(value: 0, label: Text('Completa')), ButtonSegment(value: 1, label: Text('Iguales')), ButtonSegment(value: 2, label: Text('Por productos'))],
              selected: {_mode}, onSelectionChanged: (s) => setState(() => _mode = s.first)),
            if (_mode != 0) ...[
              const SizedBox(height: 10),
              Row(children: [
                const Text('Personas:', style: TextStyle(fontWeight: FontWeight.w600)), const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: _persons > 2 ? () => setState(() => _persons--) : null),
                Text('$_persons', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: _persons < 10 ? () => setState(() => _persons++) : null),
              ]),
            ],
            if (_mode == 2) ...[
              const Divider(),
              const Text('Asigna cada producto a una persona', style: TextStyle(fontWeight: FontWeight.w600)),
              for (var i = 0; i < lines.length; i++)
                ListTile(dense: true, contentPadding: EdgeInsets.zero,
                  title: Text('${lines[i].qty}  ${lines[i].name}', style: const TextStyle(fontSize: 13)),
                  subtitle: Text(usd(lines[i].lineUsd), style: const TextStyle(fontSize: 11.5)),
                  trailing: DropdownButton<int>(
                    value: (_assign[i] ?? 0).clamp(0, _persons - 1).toInt(),
                    items: [for (var p = 0; p < _persons; p++) DropdownMenuItem(value: p, child: Text('Persona ${p + 1}'))],
                    onChanged: (v) => setState(() => _assign[i] = v ?? 0))),
            ],
            const Divider(height: 24),
            const Text('Pago', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            for (var i = 0; i < parts.length; i++)
              Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Text(parts.length == 1 ? 'Monto' : 'Persona ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w600)), const Spacer(), Text(dualUsd(parts[i]), style: const TextStyle(fontWeight: FontWeight.bold))]),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, children: [for (final m in store.methods) ChoiceChip(label: Text(m, style: const TextStyle(fontSize: 12)), selected: (_method[i] ?? store.methods.first) == m, onSelected: (_) => setState(() => _method[i] = m))]),
                  const SizedBox(height: 8),
                  TextField(controller: _refFor(i), style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(isDense: true, labelText: 'Referencia bancaria (opcional)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.confirmation_number_outlined))),
                ]))),
          ])),
          SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(12),
            child: SizedBox(width: double.infinity, height: 52, child: FilledButton.icon(
              onPressed: (lines.isEmpty || _paying) ? null : _confirm,
              icon: _paying ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check),
              label: Text(_paying ? 'Procesando...' : 'Confirmar cobro'))))),
        ]);
      }),
    );
  }
}

// ======================= COMPROBANTE =======================
class ReceiptScreen extends StatelessWidget {
  final int table;
  const ReceiptScreen({super.key, required this.table});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comprobante')),
      body: AnimatedBuilder(animation: store, builder: (context, _) {
        final acc = store.account(table);
        final total = store.accountTotalUsd(table);
        final now = DateTime.now();
        final t = store.tables.where((e) => e.number == table).toList();
        final waiter = t.isNotEmpty ? (t.first.waiter ?? '-') : '-';
        const mono = TextStyle(fontFamily: 'monospace', fontSize: 13.5, height: 1.4, color: Colors.black);
        return Center(child: SingleChildScrollView(child: Container(
          margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(18),
          constraints: const BoxConstraints(maxWidth: 360), color: Colors.white,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            const Center(child: Text('PUESTO DE COMIDA', style: TextStyle(fontFamily: 'monospace', fontSize: 15, fontWeight: FontWeight.bold))),
            const Center(child: Text('PRECUENTA (no fiscal)', style: mono)),
            const Text('------------------------------', style: mono),
            Text('MESA $table', style: mono.copyWith(fontWeight: FontWeight.bold)),
            Text('${two(now.day)}/${two(now.month)}/${now.year}  ${hhmm(now)}', style: mono),
            Text('MESERO: $waiter', style: mono),
            const Text('------------------------------', style: mono),
            for (final a in acc) ...[
              Text('${a.qty} x ${a.name}', style: mono.copyWith(fontWeight: FontWeight.w600)),
              if (a.size != null || a.extras.isNotEmpty || a.quita.isNotEmpty)
                Text('   ${[if (a.size != null) a.size!, ...a.extras.map((e) => '+$e'), ...a.quita.map((q) => 'sin $q')].join(', ')}', style: mono.copyWith(fontSize: 12)),
              Text('   ${usd(a.lineUsd)}   ${ves(a.lineUsd * store.rate)}', style: mono),
            ],
            const Text('------------------------------', style: mono),
            Text('TOTAL: ${usd(total)}', style: mono.copyWith(fontWeight: FontWeight.bold, fontSize: 15)),
            Text('       ${ves(total * store.rate)}', style: mono.copyWith(fontWeight: FontWeight.bold)),
            Text('Tasa: ${ves(store.rate)} / \$', style: mono.copyWith(fontSize: 11)),
            const SizedBox(height: 14),
            Center(child: FilledButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impresion por Bluetooth se agrega en la Entrega 4'))),
              icon: const Icon(Icons.print), label: const Text('Imprimir'))),
          ]),
        )));
      }),
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
  int _lastCount = -1;
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
  Color _c(String s) => switch (s) { 'nueva' => const Color(0xFF42A5F5), 'preparando' => const Color(0xFFFFA726), 'lista' => const Color(0xFF66BB6A), _ => Colors.grey };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF263238),
      appBar: AppBar(title: const Text('Cocina - Comandas')),
      body: AnimatedBuilder(animation: store, builder: (context, _) {
        final list = store.tickets.where((t) => t.status != 'entregada' && t.status != 'anulada').toList();
        if (list.length > _lastCount && _lastCount != -1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('🔔 Nueva comanda recibida'), duration: Duration(seconds: 2), backgroundColor: kPrimary));
          });
        }
        _lastCount = list.length;
        if (list.isEmpty) return const Center(child: Text('Sin comandas pendientes', style: TextStyle(color: Colors.white70, fontSize: 18)));
        return LayoutBuilder(builder: (context, cns) {
          final cols = (cns.maxWidth / 300).floor().clamp(1, 5).toInt();
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.72),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final t = list[i];
              final c = _c(t.status);
              return Card(color: Colors.white, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(color: c, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Row(children: [
                  Text('#${t.number.toString().padLeft(6, '0')}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(), const Icon(Icons.timer, color: Colors.white, size: 15), const SizedBox(width: 3),
                  Text(_elapsed(t.sentAt), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ])),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Row(children: [
                  Text(t.table != null ? 'MESA ${t.table}' : 'PARA LLEVAR', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (t.adicion) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), color: Colors.amber, child: const Text('ADICION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                ])),
                Text(t.waiter, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                const Divider(height: 10),
                Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 12), children: [
                  for (final l in t.lines) ...[
                    Text('${l.qty}  ${l.name}${l.size != null ? ' (${l.size})' : ''}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    for (final e in l.extras) Text('   + $e', style: const TextStyle(fontSize: 12.5, color: Color(0xFF2E7D32))),
                    for (final q in l.quita) Text('   - Sin $q', style: const TextStyle(fontSize: 12.5, color: Colors.red)),
                    if (l.note != null) Text('   * ${l.note}', style: const TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 3),
                  ],
                  if (t.note != null) ...[const Divider(), Text('OBS: ${t.note}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))],
                  if (t.reprinted) const Center(child: Text('** REIMPRESION **', style: TextStyle(fontWeight: FontWeight.bold))),
                ])),
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  IconButton(tooltip: 'Reimprimir', icon: const Icon(Icons.print), onPressed: () {
                    store.reprint(t);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('REIMPRESION registrada (impresora real en Entrega 4)')));
                  }),
                  IconButton(tooltip: 'Anular', icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () => store.cancelTicket(t)),
                ]),
                Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 8), child: SizedBox(width: double.infinity, child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: c), onPressed: () => store.advance(t),
                  child: Text(switch (t.status) { 'nueva' => 'Empezar a preparar', 'preparando' => 'Marcar lista', 'lista' => 'Marcar entregada', _ => t.status })))),
              ]));
            },
          );
        });
      }),
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
  final _rate = TextEditingController();
  @override
  void initState() { super.initState(); _rate.text = store.rate.toStringAsFixed(2); }
  @override
  void dispose() { _rate.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Administrador')),
      body: AnimatedBuilder(animation: store, builder: (context, _) => ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Tasa de cambio (Bs por 1 USD)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
          const Text('1 USD =  ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: TextField(controller: _rate, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(suffixText: 'Bs', isDense: true, border: OutlineInputBorder()))),
          const SizedBox(width: 8),
          FilledButton(onPressed: () async {
            final v = double.tryParse(_rate.text.replaceAll(',', '.'));
            if (v != null && v > 0) {
              await store.setRate(v);
              if (!context.mounted) return;
              FocusScope.of(context).unfocus();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tasa actualizada')));
            }
          }, child: const Text('Guardar')),
        ]))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: FilledButton.tonalIcon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductForm())), icon: const Icon(Icons.add), label: const Text('Nuevo producto'))),
          const SizedBox(width: 8),
          Expanded(child: FilledButton.tonalIcon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())), icon: const Icon(Icons.history), label: const Text('Historial hoy'))),
        ]),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: FilledButton.tonalIcon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen())),
          icon: const Icon(Icons.inventory_2), label: const Text('Inventario de ingredientes'))),
        if (store.lowStock.isNotEmpty) ...[lowStockCard(), const SizedBox(height: 12)],
        const Divider(height: 28),
        const Text('Productos y precios (toca para editar)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (store.products.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('Cargando productos...', style: TextStyle(color: Colors.grey))),
        for (final c in Cat.values) ...[
          if (store.products.any((p) => p.cat == c)) ...[
            Padding(padding: const EdgeInsets.only(top: 8, bottom: 4), child: Text(catLabel(c), style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimary))),
            for (final p in store.products.where((p) => p.cat == c))
              Card(margin: const EdgeInsets.only(bottom: 6), child: ListTile(
                leading: Text(p.emoji, style: const TextStyle(fontSize: 24)),
                title: Text(p.name),
                subtitle: Text('${dualPrice(p.price, p.cur)}${p.trackStock ? '  ·  stock: ${p.stock.toStringAsFixed(0)}' : ''}${store.maxMakeable(p) >= 0 ? '  ·  alcanza ~${store.maxMakeable(p)}' : ''}', style: const TextStyle(fontSize: 11.5)),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductForm(existing: p))),
                trailing: Switch(value: p.available, onChanged: (_) => store.toggleProduct(p)))),
          ],
        ],
      ])),
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
  late TextEditingController _name, _emoji, _price, _quita, _stock, _minStock;
  late Cat _cat;
  late Currency _cur;
  late bool _available, _useSizes, _track;
  final List<List<TextEditingController>> _extras = [];
  final List<_RRow> _recipeRows = [];
  final List<_CRow> _comboRows = [];
  bool _saving = false;
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
    _track = e?.trackStock ?? false;
    _stock = TextEditingController(text: e != null ? e.stock.toStringAsFixed(0) : '0');
    _minStock = TextEditingController(text: e != null ? e.minStock.toStringAsFixed(0) : '0');
    if (e != null) for (final ex in e.extras) { _extras.add([TextEditingController(text: ex.name), TextEditingController(text: ex.price.toStringAsFixed(2))]); }
    if (e != null) {
      for (final r in e.recipe) { _recipeRows.add(_RRow(r.ingredientId, TextEditingController(text: fmtQty(r.qty)))); }
      for (final c in e.comboItems) { _comboRows.add(_CRow(c.productId, TextEditingController(text: fmtQty(c.qty)))); }
    }
  }
  @override
  void dispose() {
    _name.dispose(); _emoji.dispose(); _price.dispose(); _quita.dispose(); _stock.dispose(); _minStock.dispose();
    for (final row in _extras) { for (final c in row) { c.dispose(); } }
    for (final r in _recipeRows) { r.qty.dispose(); }
    for (final c in _comboRows) { c.qty.dispose(); }
    super.dispose();
  }
  Future<void> _save() async {
    if (_saving) return;
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
      if (n.isNotEmpty) extras.add(Extra('e${i + 1}', n, pr));
    }
    final quita = _quita.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final emoji = _emoji.text.trim().isEmpty ? '🍽️' : _emoji.text.trim();
    final stock = double.tryParse(_stock.text.replaceAll(',', '.')) ?? 0;
    final minStock = double.tryParse(_minStock.text.replaceAll(',', '.')) ?? 0;
    final recipe = <RecipeItem>[
      for (final r in _recipeRows)
        if (r.ingredientId != null) RecipeItem(r.ingredientId!, double.tryParse(r.qty.text.replaceAll(',', '.')) ?? 0),
    ];
    final comboItems = <ComboItem>[
      for (final c in _comboRows)
        if (c.productId != null) ComboItem(c.productId!, double.tryParse(c.qty.text.replaceAll(',', '.')) ?? 0),
    ];
    setState(() => _saving = true);
    final e = widget.existing;
    if (e != null) {
      e.name = name; e.emoji = emoji; e.cat = _cat; e.price = price; e.cur = _cur;
      e.available = _available; e.sizes = sizes; e.extras = extras; e.quita = quita;
      e.stock = stock; e.minStock = minStock; e.trackStock = _track;
      e.recipe = _cat == Cat.combos ? <RecipeItem>[] : recipe;
      e.comboItems = _cat == Cat.combos ? comboItems : <ComboItem>[];
      await store.updateProduct(e);
    } else {
      await store.addProduct(Product('', name, emoji, _cat, price, _cur, sizes: sizes, extras: extras, quita: quita, available: _available, stock: stock, minStock: minStock, trackStock: _track, recipe: _cat == Cat.combos ? <RecipeItem>[] : recipe, comboItems: _cat == Cat.combos ? comboItems : <ComboItem>[]));
    }
    if (!mounted) return;
    Navigator.pop(context);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'Nuevo producto' : 'Editar producto'), actions: [
        if (widget.existing != null)
          IconButton(icon: const Icon(Icons.delete), onPressed: () {
            showDialog<void>(context: context, builder: (dctx) => AlertDialog(
              title: const Text('Eliminar producto'),
              content: Text('Eliminar "${widget.existing!.name}"?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Cancelar')),
                FilledButton(onPressed: () async {
                  Navigator.pop(dctx);
                  await store.deleteProduct(widget.existing!);
                  if (mounted) Navigator.pop(context);
                }, child: const Text('Eliminar')),
              ]));
          }),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        Row(children: [
          SizedBox(width: 90, child: TextField(controller: _emoji, textAlign: TextAlign.center, decoration: const InputDecoration(labelText: 'Icono', border: OutlineInputBorder()))),
          const SizedBox(width: 12),
          Expanded(child: DropdownButtonFormField<Cat>(value: _cat,
            decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
            items: [for (final c in Cat.values) DropdownMenuItem(value: c, child: Text(catLabel(c)))],
            onChanged: (v) => setState(() => _cat = v ?? Cat.otros))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: _price, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Precio', border: OutlineInputBorder()))),
          const SizedBox(width: 12),
          SegmentedButton<Currency>(segments: const [ButtonSegment(value: Currency.usd, label: Text('USD')), ButtonSegment(value: Currency.ves, label: Text('Bs'))],
              selected: {_cur}, onSelectionChanged: (s) => setState(() => _cur = s.first)),
        ]),
        const SizedBox(height: 6),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Disponible'), value: _available, onChanged: (v) => setState(() => _available = v)),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Usar tamanos (Pequena/Mediana/Grande)'), value: _useSizes, onChanged: (v) => setState(() => _useSizes = v)),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Controlar inventario'), subtitle: const Text('Descuenta del stock al vender y avisa cuando esta por agotarse'), value: _track, onChanged: (v) => setState(() => _track = v)),
        if (_track) Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
          Expanded(child: TextField(controller: _stock, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Stock actual', isDense: true, border: OutlineInputBorder()))),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: _minStock, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Stock minimo (alerta)', isDense: true, border: OutlineInputBorder()))),
        ])),
        const SizedBox(height: 6),
        TextField(controller: _quita, decoration: const InputDecoration(labelText: 'Ingredientes que se pueden quitar (separados por coma)', hintText: 'Cebolla, Tomate, Salsas', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        Row(children: [
          const Text('Extras', style: TextStyle(fontWeight: FontWeight.bold)), const Spacer(),
          TextButton.icon(onPressed: () => setState(() => _extras.add([TextEditingController(), TextEditingController(text: '0')])), icon: const Icon(Icons.add), label: const Text('Agregar extra')),
        ]),
        for (var i = 0; i < _extras.length; i++)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
            Expanded(flex: 3, child: TextField(controller: _extras[i][0], decoration: const InputDecoration(labelText: 'Nombre extra', isDense: true, border: OutlineInputBorder()))),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: TextField(controller: _extras[i][1], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Precio', isDense: true, border: OutlineInputBorder()))),
            IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () => setState(() { _extras[i][0].dispose(); _extras[i][1].dispose(); _extras.removeAt(i); })),
          ])),
        const Divider(height: 24),
        if (_cat == Cat.combos) ...[
          Row(children: [
            const Expanded(child: Text('Componentes del combo', style: TextStyle(fontWeight: FontWeight.bold))),
            TextButton.icon(onPressed: () => setState(() => _comboRows.add(_CRow(null, TextEditingController(text: '1')))), icon: const Icon(Icons.add), label: const Text('Agregar')),
          ]),
          const Text('Elige productos ya creados y su cantidad. El precio del combo lo pones tu arriba (no se suma solo).', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
          for (var i = 0; i < _comboRows.length; i++)
            Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [
              Expanded(flex: 3, child: DropdownButtonFormField<String>(
                value: store.products.any((x) => x.id == _comboRows[i].productId && x.cat != Cat.combos) ? _comboRows[i].productId : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Producto', isDense: true, border: OutlineInputBorder()),
                items: [for (final pr in store.products.where((x) => x.cat != Cat.combos)) DropdownMenuItem(value: pr.id, child: Text(pr.name, overflow: TextOverflow.ellipsis))],
                onChanged: (v) => setState(() => _comboRows[i].productId = v))),
              const SizedBox(width: 8),
              SizedBox(width: 64, child: TextField(controller: _comboRows[i].qty, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Cant.', isDense: true, border: OutlineInputBorder()))),
              IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () => setState(() { _comboRows[i].qty.dispose(); _comboRows.removeAt(i); })),
            ])),
        ] else ...[
          Row(children: [
            const Expanded(child: Text('Receta (ingredientes)', style: TextStyle(fontWeight: FontWeight.bold))),
            TextButton.icon(onPressed: () => setState(() => _recipeRows.add(_RRow(null, TextEditingController(text: '1')))), icon: const Icon(Icons.add), label: const Text('Agregar')),
          ]),
          const Text('Que ingredientes consume y cuanto. Se descuentan del inventario al vender.', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
          if (store.ingredients.isEmpty)
            const Padding(padding: EdgeInsets.only(top: 6), child: Text('Primero agrega ingredientes en el Inventario.', style: TextStyle(fontSize: 12, color: Colors.red))),
          for (var i = 0; i < _recipeRows.length; i++)
            Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [
              Expanded(flex: 3, child: DropdownButtonFormField<String>(
                value: store.ingredients.any((ing) => ing.id == _recipeRows[i].ingredientId) ? _recipeRows[i].ingredientId : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Ingrediente', isDense: true, border: OutlineInputBorder()),
                items: [for (final ing in store.ingredients) DropdownMenuItem(value: ing.id, child: Text('${ing.name} (${ing.unit})', overflow: TextOverflow.ellipsis))],
                onChanged: (v) => setState(() => _recipeRows[i].ingredientId = v))),
              const SizedBox(width: 8),
              SizedBox(width: 64, child: TextField(controller: _recipeRows[i].qty, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Cant.', isDense: true, border: OutlineInputBorder()))),
              IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () => setState(() { _recipeRows[i].qty.dispose(); _recipeRows.removeAt(i); })),
            ])),
        ],
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 50, child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
          label: Text(_saving ? 'Guardando...' : 'Guardar producto'))),
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
      body: AnimatedBuilder(animation: store, builder: (context, _) {
        final sales = store.todaySales;
        final units = store.unitsToday();
        final byMethod = store.byMethodToday();
        final sortedUnits = units.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        return ListView(padding: const EdgeInsets.all(16), children: [
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DaySummaryScreen())),
            icon: const Icon(Icons.print), label: const Text('Resumen para imprimir'))),
          const SizedBox(height: 12),
          Card(color: kPrimary.withOpacity(0.08), child: Padding(padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Ventas de hoy', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(dualUsd(store.todayTotalUsd), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text('${sales.length} cuentas cobradas'),
            ]))),
          const SizedBox(height: 12),
          const Text('Por medio de pago', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          if (byMethod.isEmpty) const Text('Sin ventas aun', style: TextStyle(color: Colors.grey))
          else for (final e in byMethod.entries)
            ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.payments), title: Text(e.key), trailing: Text(dualUsd(e.value), style: const TextStyle(fontWeight: FontWeight.w600))),
          const Divider(height: 24),
          const Text('Unidades vendidas por producto', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          if (sortedUnits.isEmpty) const Text('Sin ventas aun', style: TextStyle(color: Colors.grey))
          else for (final e in sortedUnits)
            ListTile(dense: true, contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(radius: 15, backgroundColor: Colors.orange.shade50, child: Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              title: Text(e.key)),
          const Divider(height: 24),
          const Text('Detalle de cuentas', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          if (sales.isEmpty) const Text('Sin ventas aun', style: TextStyle(color: Colors.grey))
          else for (final s in sales)
            Card(margin: const EdgeInsets.only(bottom: 6), child: ListTile(
              title: Text('${s.table != null ? 'Mesa ${s.table}' : 'Para llevar'}  ·  ${hhmm(s.at)}'),
              subtitle: Text(s.payments.map((p) => p.reference != null && p.reference!.isNotEmpty ? '${p.method} (ref ${p.reference})' : p.method).join(', ')),
              trailing: Text(usd(s.totalUsd), style: const TextStyle(fontWeight: FontWeight.bold)))),
        ]);
      }),
    );
  }
}

// ======================= INGREDIENTES (INVENTARIO) =======================
String fmtQty(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

class Ingredient {
  String id;
  String name;
  String unit;
  double stock;
  double minStock;
  Ingredient(this.id, this.name, this.unit, this.stock, this.minStock);
  factory Ingredient.fromRow(Map<String, dynamic> r) => Ingredient(
        r['id'] as String,
        (r['name'] ?? '') as String,
        (r['unit'] ?? 'unidad') as String,
        ((r['stock'] ?? 0) as num).toDouble(),
        ((r['min_stock'] ?? 0) as num).toDouble(),
      );
  Map<String, dynamic> toRow() => <String, dynamic>{'name': name, 'unit': unit, 'stock': stock, 'min_stock': minStock};
  bool get low => stock <= minStock;
}

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventario de ingredientes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IngredientForm())),
        icon: const Icon(Icons.add), label: const Text('Nuevo')),
      body: AnimatedBuilder(animation: store, builder: (context, _) {
        final low = store.lowIngredients;
        final list = store.ingredients;
        return ListView(padding: const EdgeInsets.all(16), children: [
          if (low.isNotEmpty) ...[
            Card(color: Colors.red.shade50, child: Padding(padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: const [Icon(Icons.warning_amber, color: Colors.red), SizedBox(width: 8),
                  Text('Ingredientes por agotarse', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red))]),
                const SizedBox(height: 6),
                for (final i in low)
                  Text('- ${i.name}: ${i.stock <= 0 ? 'AGOTADO' : 'quedan ${fmtQty(i.stock)} ${i.unit}'}',
                      style: const TextStyle(fontSize: 12.5)),
              ]))),
            const SizedBox(height: 12),
          ],
          if (list.isEmpty)
            const Padding(padding: EdgeInsets.all(24),
              child: Center(child: Text('Aun no hay ingredientes.\nToca "Nuevo" para agregar.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)))),
          for (final i in list)
            Card(margin: const EdgeInsets.only(bottom: 6), child: ListTile(
              leading: CircleAvatar(
                backgroundColor: i.low ? Colors.red.shade100 : Colors.green.shade100,
                child: Icon(Icons.restaurant, color: i.low ? Colors.red : Colors.green, size: 20)),
              title: Text(i.name),
              subtitle: Text('Stock: ${fmtQty(i.stock)} ${i.unit}  ·  minimo: ${fmtQty(i.minStock)} ${i.unit}', style: const TextStyle(fontSize: 12)),
              trailing: i.low ? const Icon(Icons.error, color: Colors.red) : const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => IngredientForm(existing: i))),
            )),
        ]);
      }),
    );
  }
}

class IngredientForm extends StatefulWidget {
  final Ingredient? existing;
  const IngredientForm({super.key, this.existing});
  @override
  State<IngredientForm> createState() => _IngredientFormState();
}
class _IngredientFormState extends State<IngredientForm> {
  static const _units = ['kg', 'g', 'unidad', 'litro', 'ml', 'paquete', 'bolsa'];
  late TextEditingController _name, _stock, _minStock;
  late String _unit;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _stock = TextEditingController(text: e != null ? fmtQty(e.stock) : '0');
    _minStock = TextEditingController(text: e != null ? fmtQty(e.minStock) : '0');
    _unit = e?.unit ?? 'kg';
    if (!_units.contains(_unit)) _unit = 'kg';
  }
  @override
  void dispose() { _name.dispose(); _stock.dispose(); _minStock.dispose(); super.dispose(); }
  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escribe el nombre'))); return; }
    final stock = double.tryParse(_stock.text.replaceAll(',', '.')) ?? 0;
    final minStock = double.tryParse(_minStock.text.replaceAll(',', '.')) ?? 0;
    setState(() => _saving = true);
    final e = widget.existing;
    if (e != null) { e.name = name; e.unit = _unit; e.stock = stock; e.minStock = minStock; await store.updateIngredient(e); }
    else { await store.addIngredient(Ingredient('', name, _unit, stock, minStock)); }
    if (!mounted) return;
    Navigator.pop(context);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'Nuevo ingrediente' : 'Editar ingrediente'), actions: [
        if (widget.existing != null)
          IconButton(icon: const Icon(Icons.delete), onPressed: () {
            showDialog<void>(context: context, builder: (dctx) => AlertDialog(
              title: const Text('Eliminar ingrediente'),
              content: Text('Eliminar "${widget.existing!.name}"?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Cancelar')),
                FilledButton(onPressed: () async { Navigator.pop(dctx); await store.deleteIngredient(widget.existing!); if (mounted) Navigator.pop(context); }, child: const Text('Eliminar')),
              ]));
          }),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nombre del ingrediente', hintText: 'Ej: Carne molida, Queso, Huevos', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: _unit,
          decoration: const InputDecoration(labelText: 'Unidad de medida', border: OutlineInputBorder()),
          items: [for (final u in _units) DropdownMenuItem(value: u, child: Text(u))],
          onChanged: (v) => setState(() => _unit = v ?? 'kg')),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: _stock, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Stock actual', border: OutlineInputBorder()))),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: _minStock, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Stock minimo (alerta)', border: OutlineInputBorder()))),
        ]),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 50, child: FilledButton.icon(onPressed: _saving ? null : _save,
          icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
          label: Text(_saving ? 'Guardando...' : 'Guardar ingrediente'))),
      ]),
    );
  }
}

// ======================= RESUMEN DEL DIA (IMPRIMIBLE) =======================
class DaySummaryScreen extends StatelessWidget {
  const DaySummaryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resumen del dia')),
      body: AnimatedBuilder(animation: store, builder: (context, _) {
        final sales = store.todaySales;
        final units = store.unitsToday().entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final byMethod = store.byMethodToday();
        final total = store.todayTotalUsd;
        final now = DateTime.now();
        const mono = TextStyle(fontFamily: 'monospace', fontSize: 13.5, height: 1.5, color: Colors.black);
        return Center(child: SingleChildScrollView(child: Container(
          margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(18),
          constraints: const BoxConstraints(maxWidth: 380), color: Colors.white,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            const Center(child: Text('RESUMEN DEL DIA', style: TextStyle(fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.bold))),
            Center(child: Text('${two(now.day)}/${two(now.month)}/${now.year}  ${hhmm(now)}', style: mono)),
            const Text('==============================', style: mono),
            const Text('PRODUCTOS VENDIDOS', style: mono),
            if (units.isEmpty) const Text('  (sin ventas)', style: mono)
            else for (final e in units) Text('  ${e.value} x ${e.key}', style: mono),
            const Text('------------------------------', style: mono),
            const Text('INGRESOS POR METODO', style: mono),
            if (byMethod.isEmpty) const Text('  (sin ventas)', style: mono)
            else for (final e in byMethod.entries) Text('  ${e.key}: ${usd(e.value)}  |  ${ves(e.value * store.rate)}', style: mono),
            const Text('==============================', style: mono),
            Text('TOTAL: ${usd(total)}', style: mono.copyWith(fontWeight: FontWeight.bold, fontSize: 15)),
            Text('       ${ves(total * store.rate)}', style: mono.copyWith(fontWeight: FontWeight.bold)),
            Text('Cuentas cobradas: ${sales.length}', style: mono),
            Text('Tasa: ${ves(store.rate)} / \$', style: mono.copyWith(fontSize: 11)),
            const SizedBox(height: 14),
            Center(child: FilledButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impresion por Bluetooth se agrega en la Entrega 4'))),
              icon: const Icon(Icons.print), label: const Text('Imprimir'))),
          ]),
        )));
      }),
    );
  }
}


// ======================= RECETAS Y COMBOS (modelos) =======================
class RecipeItem {
  String ingredientId;
  double qty;
  RecipeItem(this.ingredientId, this.qty);
}
class ComboItem {
  String productId;
  double qty;
  ComboItem(this.productId, this.qty);
}
class _RRow {
  String? ingredientId;
  final TextEditingController qty;
  _RRow(this.ingredientId, this.qty);
}
class _CRow {
  String? productId;
  final TextEditingController qty;
  _CRow(this.productId, this.qty);
}
