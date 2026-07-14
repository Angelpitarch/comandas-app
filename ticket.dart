import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/auth/profile_selector_screen.dart';
import '../../features/tables/tables_screen.dart';
import '../../features/order/order_screen.dart';
import '../../features/kitchen/kitchen_screen.dart';
import '../../features/admin/admin_home_screen.dart';
import '../../features/settings/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/perfil', builder: (c, s) => const ProfileSelectorScreen()),
      GoRoute(path: '/mesas', builder: (c, s) => const TablesScreen()),
      GoRoute(
        path: '/pedido/:orderId',
        builder: (c, s) =>
            OrderScreen(orderId: s.pathParameters['orderId']!),
      ),
      GoRoute(path: '/cocina', builder: (c, s) => const KitchenScreen()),
      GoRoute(path: '/admin', builder: (c, s) => const AdminHomeScreen()),
      GoRoute(path: '/config', builder: (c, s) => const SettingsScreen()),
    ],
  );
});
