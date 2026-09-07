import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';
import 'auth_state.dart';
import 'permissions.dart';

/// `true` quando há uma sessão completa (autenticado + com empresa).
final isSignedInProvider = Provider<bool>(
  (ref) => ref.watch(authControllerProvider) is AuthSignedIn,
);

/// Id da empresa ativa, ou `null` se ainda não houver sessão completa.
///
/// Os repositórios dependem deste provider para isolar os dados por empresa.
final currentEmpresaIdProvider = Provider<String?>((ref) {
  final state = ref.watch(authControllerProvider);
  return state is AuthSignedIn ? state.empresaId : null;
});

/// Papel do utilizador na empresa ativa (por omissão, o mais restritivo).
final currentPapelProvider = Provider<Papel>((ref) {
  final state = ref.watch(authControllerProvider);
  return state is AuthSignedIn ? state.papel : Papel.viewer;
});

/// Nome apresentável do utilizador autenticado.
final currentUserNameProvider = Provider<String?>((ref) {
  final state = ref.watch(authControllerProvider);
  return switch (state) {
    AuthSignedIn(:final nome) => nome,
    AuthNeedsOnboarding(:final user) => user.getStringValue('email'),
    _ => null,
  };
});

/// Id da empresa ativa; lança se chamado sem sessão completa.
/// Conveniência para repositórios que só correm autenticados.
String requireEmpresaId(Ref ref) {
  final id = ref.watch(currentEmpresaIdProvider);
  if (id == null) {
    throw StateError('Operação requer uma empresa ativa.');
  }
  return id;
}
