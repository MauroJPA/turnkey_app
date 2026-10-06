import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../errors/erro_ligacao.dart';
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

  /// Entra com email e palavra-passe. Devolve `null` se ficou com a sessão
  /// iniciada, ou o `mfaId` se o servidor exige ainda o código enviado por
  /// email (verificação em 2 passos dos administradores).
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _pb.collection('users').authWithPassword(email, password);
      return null;
    } on ClientException catch (e) {
      final mfa = e.response['mfaId'];
      if (e.statusCode == 401 && mfa is String && mfa.isNotEmpty) return mfa;
      rethrow;
    }
  }

  /// Pede o código de 6 dígitos por email; devolve o `otpId` do pedido.
  Future<String> pedirCodigo(String email) async {
    final r = await _pb.collection('users').requestOTP(email);
    return r.otpId;
  }

  /// Segundo passo: o código recebido por email, mais o `mfaId` do primeiro.
  Future<void> entrarComCodigo({
    required String otpId,
    required String codigo,
    required String mfaId,
  }) async {
    await _pb
        .collection('users')
        .authWithOTP(otpId, codigo, body: {'mfaId': mfaId});
  }

  /// Cria a conta e deixa a sessão iniciada.
  Future<void> register({
    required String email,
    required String password,
    required String nome,
  }) async {
    await _pb
        .collection('users')
        .create(
          body: {
            'email': email,
            'password': password,
            'passwordConfirm': password,
            'nome': nome,
          },
        );
    await signIn(email: email, password: password);
  }

  /// Revalida o token; se o servidor o recusar, limpa a sessão. Sem ligação
  /// ao servidor (Wi-Fi em baixo) **não** termina a sessão: a pessoa continua
  /// entrada com o que a app guardou, e volta a validar quando houver rede.
  Future<void> refresh() async {
    if (!_pb.authStore.isValid) return;
    try {
      await _pb.collection('users').authRefresh();
    } on ClientException catch (e) {
      if (eErroDeLigacao(e)) return;
      _pb.authStore.clear();
    }
  }

  /// Relê o registo do utilizador autenticado (para apanhar `empresa`/`papel`).
  Future<RecordModel> reloadCurrentUser() {
    final id = _pb.authStore.record!.id;
    return _pb.collection('users').getOne(id);
  }

  void signOut() => _pb.authStore.clear();

  // --- OAuth (Google / Apple) via o fluxo OAuth2 do PocketBase ------------

  /// Nomes dos provedores OAuth2 que o servidor tem ativos
  /// (ex.: `['google', 'apple']`). Vazio se nenhum estiver configurado.
  Future<List<String>> enabledOAuthProviders() async {
    try {
      final methods = await _pb.collection('users').listAuthMethods();
      return methods.oauth2.providers.map((p) => p.name).toList();
    } on Object {
      return const [];
    }
  }

  /// Autentica com um provedor OAuth2 ([provider] = `google` | `apple` | …).
  /// Abre o browser; o PocketBase trata da troca de tokens.
  Future<void> signInWithOAuth2(String provider) {
    return _pb.collection('users').authWithOAuth2(provider, (url) async {
      final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!ok) {
        throw Exception('Não foi possível abrir o browser para o login.');
      }
    });
  }
}
