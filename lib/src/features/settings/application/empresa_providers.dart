import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_user.dart';
import '../data/empresa_repository.dart';
import '../domain/empresa.dart';

/// A empresa ativa (a do utilizador autenticado).
final currentEmpresaProvider = FutureProvider<Empresa?>((ref) async {
  final id = ref.watch(currentEmpresaIdProvider);
  if (id == null) return null;
  return ref.watch(empresaRepositoryProvider).getById(id);
});
