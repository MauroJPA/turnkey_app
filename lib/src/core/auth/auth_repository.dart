import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../pocketbase/pb_client.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(pbProvider)),
);

/// Acesso à autenticação do PocketBase (coleção `users`).
///
/// Não classifica o estado da app — isso é do `AuthController`. Aqui só ficam
/// as operações cruas contra o servidor.
class AuthRepository {
  AuthRepository(this._pb);

  final PocketBase _pb;

  bool get isSignedIn => _pb.authStore.isValid;

  RecordModel? get currentRecord => _pb.authStore.record;

  /// Emite sempre que o token/registo de sessão muda.
  Stream<void> authChanges() => _pb.authStore.onChange.map((_) {});

  Future<void> signIn({required String email, required String password}) {
    return _pb.collection('users').authWithPassword(email, password);
  }

  /// Cria a conta e deixa a sessão iniciada.
  Future<void> register({
    required String email,
    required String password,
    required String nome,
  }) async {
    await _pb.collection('users').create(
      body: {
        'email': email,
        'password': password,
        'passwordConfirm': password,
        'nome': nome,
      },
    );
    await signIn(email: email, password: password);
  }

  /// Revalida o token; se falhar, limpa a sessão.
  Future<void> refresh() async {
    if (!_pb.authStore.isValid) return;
    try {
      await _pb.collection('users').authRefresh();
    } on ClientException {
      _pb.authStore.clear();
    }
  }

  /// Relê o registo do utilizador autenticado (para apanhar `empresa`/`papel`).
  Future<RecordModel> reloadCurrentUser() {
    final id = _pb.authStore.record!.id;
    return _pb.collection('users').getOne(id);
  }

  void signOut() => _pb.authStore.clear();

  // --- OAuth (preparado; ativado numa iteração posterior) ------------------
  static const oauthDisponivel = false;

  Future<void> signInWithGoogle() =>
      throw UnimplementedError('Login com Google ativado numa fase posterior.');

  Future<void> signInWithApple() =>
      throw UnimplementedError('Login com Apple ativado numa fase posterior.');
}
