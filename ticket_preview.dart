import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/enums.dart';
import '../../domain/models/user.dart';
import '../demo_data.dart';

/// Lista de usuarios de prueba.
final usersProvider = Provider<List<AppUser>>((ref) => DemoData.users);

/// Usuario autenticado por PIN.
final currentUserProvider = StateProvider<AppUser?>((ref) => null);

/// Perfil activo elegido en el selector (Etapa 1: selector libre).
final activeRoleProvider = StateProvider<UserRole?>((ref) => null);
