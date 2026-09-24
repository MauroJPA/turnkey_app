import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_user.dart';
import '../data/navigation_repository.dart';
import '../domain/nav_config.dart';
import '../domain/nav_prefs.dart';

final navConfigProvider = FutureProvider<NavConfig>((ref) {
  return ref.watch(navigationRepositoryProvider).getConfig();
});

final navPrefsProvider = FutureProvider<NavPrefs>((ref) {
  return ref.watch(navigationRepositoryProvider).getPrefs();
});

/// Configuração já resolvida (valores por omissão enquanto carrega).
final navConfigAtualProvider = Provider<NavConfig>(
  (ref) => ref.watch(navConfigProvider).valueOrNull ?? NavConfig.vazia,
);

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

  Future<void> salvarPrefs(NavPrefs p) async {
    await _repo.salvarPrefs(p);
    _ref.invalidate(navPrefsProvider);
    await _ref.read(navPrefsProvider.future);
  }
}
