import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';
import 'auth_state.dart';
import 'permissions.dart';

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  StreamSubscription<void>? _sub;

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    _sub = _repo.authChanges().listen((_) => _reclassify());
    ref.onDispose(() => _sub?.cancel());
    // Arranque assíncrono: revalida o token e classifica.
    unawaited(_bootstrap());
    return const AuthUnknown();
  }

  Future<void> _bootstrap() async {
    try {
      await _repo.refresh();
    } finally {
      await _reclassify();
    }
  }

  /// Deriva o [AuthState] a partir da sessão atual do PocketBase.
  Future<void> _reclassify() async {
    if (!_repo.isSignedIn) {
      state = const AuthSignedOut();
      return;
    }
    try {
      final user = await _repo.reloadCurrentUser();
      final empresaId = user.getStringValue('empresa');
      if (empresaId.isEmpty && !user.getBoolValue('aprovado')) {
        state = AuthPendingApproval(user);
      } else if (empresaId.isEmpty) {
        state = AuthNeedsOnboarding(user);
      } else {
        state = AuthSignedIn(
          user: user,
          empresaId: empresaId,
          papel: Papel.fromName(user.getStringValue('papel')),
        );
      }
    } on Object {
      // Rede em baixo ou registo apagado: trata como sessão terminada.
      _repo.signOut();
      state = const AuthSignedOut(message: 'Não foi possível validar a sessão.');
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    await _repo.signIn(email: email, password: password);
    await _reclassify();
  }

  Future<void> register({
    required String email,
    required String password,
    required String nome,
  }) async {
    await _repo.register(email: email, password: password, nome: nome);
    await _reclassify();
  }

  Future<void> signInWithProvider(String provider) async {
    await _repo.signInWithOAuth2(provider);
    await _reclassify();
  }

  /// Chamado pelo ecrã de onboarding depois de criar a empresa.
  Future<void> reload() => _reclassify();

  void signOut() {
    _repo.signOut();
    state = const AuthSignedOut();
  }
}
