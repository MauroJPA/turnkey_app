import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../errors/erro_ligacao.dart';
import 'auth_repository.dart';
import 'auth_state.dart';
import 'permissions.dart';

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

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
      RecordModel user;
      try {
        user = await _repo.reloadCurrentUser();
      } on Object catch (e) {
        // Sem ligação ao servidor (Wi-Fi em baixo): continua com o registo
        // guardado da última vez (empresa e papel) em vez de pôr a pessoa
        // fora da app — assim o quiosque abre e regista sem rede.
        final guardado = _repo.currentRecord;
        if (guardado == null || !eErroDeLigacao(e)) rethrow;
        user = guardado;
      }
      state = _estadoDe(user);
    } on Object {
      // Registo apagado ou sessão recusada: trata como sessão terminada.
      _repo.signOut();
      state = const AuthSignedOut(
        message: 'Não foi possível validar a sessão.',
      );
    }
  }

  AuthState _estadoDe(RecordModel user) {
    final empresaId = user.getStringValue('empresa');
    if (empresaId.isEmpty && !user.getBoolValue('aprovado')) {
      return AuthPendingApproval(user);
    } else if (empresaId.isEmpty) {
      return AuthNeedsOnboarding(user);
    }
    return AuthSignedIn(
      user: user,
      empresaId: empresaId,
      papel: Papel.fromName(user.getStringValue('papel')),
    );
  }

  /// Devolve `null` se entrou; ou o `mfaId` se falta o código por email.
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    final mfaId = await _repo.signIn(email: email, password: password);
    if (mfaId == null) await _reclassify();
    return mfaId;
  }

  Future<String> pedirCodigo(String email) => _repo.pedirCodigo(email);

  Future<void> entrarComCodigo({
    required String otpId,
    required String codigo,
    required String mfaId,
  }) async {
    await _repo.entrarComCodigo(otpId: otpId, codigo: codigo, mfaId: mfaId);
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
