import 'package:pocketbase/pocketbase.dart';

import 'permissions.dart';

/// Estado de autenticação usado pela app e pelo router.
sealed class AuthState {
  const AuthState();
}

/// Ainda a determinar (arranque / refresh em curso).
class AuthUnknown extends AuthState {
  const AuthUnknown();
}

/// Sem sessão válida.
class AuthSignedOut extends AuthState {
  const AuthSignedOut({this.message});

  /// Mensagem opcional (ex.: sessão expirada, erro de rede no arranque).
  final String? message;
}

/// Conta criada mas ainda não aprovada pelo operador da plataforma.
class AuthPendingApproval extends AuthState {
  const AuthPendingApproval(this.user);

  final RecordModel user;
}

/// Autenticado mas ainda sem empresa associada — falta o onboarding.
class AuthNeedsOnboarding extends AuthState {
  const AuthNeedsOnboarding(this.user);

  final RecordModel user;
}

/// Autenticado e com empresa.
class AuthSignedIn extends AuthState {
  const AuthSignedIn({
    required this.user,
    required this.empresaId,
    required this.papel,
  });

  final RecordModel user;
  final String empresaId;
  final Papel papel;

  String get nome {
    final n = user.getStringValue('nome');
    return n.isNotEmpty ? n : user.getStringValue('email');
  }
}
