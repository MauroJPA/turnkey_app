import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/auth/permissions.dart';
import '../data/navigation_repository.dart';
import '../domain/nav_config.dart';
import '../domain/nav_prefs.dart';
import '../domain/papel_personalizado.dart';

final navConfigProvider = FutureProvider<NavConfig>((ref) {
  return ref.watch(navigationRepositoryProvider).getConfig();
});

final navPrefsProvider = FutureProvider<NavPrefs>((ref) {
  return ref.watch(navigationRepositoryProvider).getPrefs();
});

/// Os papéis personalizados da empresa (por nome).
final papeisPersonalizadosProvider = FutureProvider<List<PapelPersonalizado>>(
  (ref) => ref.watch(navigationRepositoryProvider).listarPapeis(),
);

/// O id do papel personalizado de quem tem a sessão aberta ('' = nenhum).
final meuPapelPersonalizadoIdProvider = Provider<String>((ref) {
  final s = ref.watch(authControllerProvider);
  return s is AuthSignedIn ? s.user.getStringValue('papel_personalizado') : '';
});

/// Configuração já resolvida (valores por omissão enquanto carrega), já com o
/// papel personalizado de quem está (se tiver um).
final navConfigAtualProvider = Provider<NavConfig>((ref) {
  final config = ref.watch(navConfigProvider).valueOrNull ?? NavConfig.vazia;
  final id = ref.watch(meuPapelPersonalizadoIdProvider);
  if (id.isEmpty) return config;
  final papeis = ref.watch(papeisPersonalizadosProvider).valueOrNull;
  return config.comMeu(papeis?.where((p) => p.id == id).firstOrNull);
});

final navPrefsAtualProvider = Provider<NavPrefs>(
  (ref) => ref.watch(navPrefsProvider).valueOrNull ?? NavPrefs.vazia,
);

/// Nível de acesso do papel atual a uma página.
final nivelAcessoProvider = Provider.family<NivelAcesso, String>((ref, chave) {
  final papel = ref.watch(currentPapelProvider);
  return ref.watch(navConfigAtualProvider).nivel(papel, chave);
});

final navigationActionsProvider = Provider<NavigationActions>(
  NavigationActions.new,
);

class NavigationActions {
  NavigationActions(this._ref);
  final Ref _ref;

  NavigationRepository get _repo => _ref.read(navigationRepositoryProvider);

  Future<void> salvarRodape(List<String> rodape) async {
    final atual = _ref.read(navConfigAtualProvider);
    await _repo.salvarRodape(atual, rodape);
    _ref.invalidate(navConfigProvider);
    await _ref.read(navConfigProvider.future);
  }

  Future<void> salvarAcesso(NavConfig novo) async {
    await _repo.salvarAcesso(
      _ref.read(navConfigAtualProvider),
      novo.acessoJson(),
    );
    _ref.invalidate(navConfigProvider);
    await _ref.read(navConfigProvider.future);
  }

  Future<PapelPersonalizado> criarPapel(String nome, Papel base) async {
    final p = await _repo.criarPapel(nome, base);
    _ref.invalidate(papeisPersonalizadosProvider);
    return p;
  }

  Future<void> guardarPapel(PapelPersonalizado p) async {
    await _repo.guardarPapel(p);
    _ref.invalidate(papeisPersonalizadosProvider);
    await _ref.read(papeisPersonalizadosProvider.future);
  }

  Future<void> apagarPapel(String id) async {
    await _repo.apagarPapel(id);
    _ref.invalidate(papeisPersonalizadosProvider);
  }

  Future<void> salvarPrefs(NavPrefs p) async {
    await _repo.salvarPrefs(p);
    _ref.invalidate(navPrefsProvider);
    await _ref.read(navPrefsProvider.future);
  }
}
