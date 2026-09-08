import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/auth/permissions.dart';
import '../../pricing/data/cost_config_repository.dart';
import '../../pricing/domain/cost_config.dart';
import '../data/empresa_repository.dart';
import '../data/team_repository.dart';
import '../domain/empresa.dart';
import '../domain/team_member.dart';
import 'empresa_providers.dart';

final teamMembersProvider = FutureProvider.autoDispose<List<TeamMember>>((ref) {
  return ref.watch(teamRepositoryProvider).listMembers();
});

final settingsActionsProvider = Provider<SettingsActions>(SettingsActions.new);

class SettingsActions {
  SettingsActions(this._ref);
  final Ref _ref;

  Future<void> saveEmpresa({
    required String nome,
    required Moeda moeda,
    required RegraArredondamento regra,
    required String corMarca,
    required TemaApp tema,
  }) async {
    final id = requireEmpresaId(_ref);
    await _ref.read(empresaRepositoryProvider).updatePerfil(
          id,
          nome: nome,
          moeda: moeda,
          regra: regra,
          corMarca: corMarca,
          tema: tema,
        );
    _ref.invalidate(currentEmpresaProvider);
  }

  Future<void> definirLogo({
    required String nome,
    required List<int> bytes,
  }) async {
    final id = requireEmpresaId(_ref);
    await _ref
        .read(empresaRepositoryProvider)
        .definirLogo(id, nome: nome, bytes: bytes);
    _ref.invalidate(currentEmpresaProvider);
  }

  Future<void> removerLogo() async {
    final id = requireEmpresaId(_ref);
    await _ref.read(empresaRepositoryProvider).removerLogo(id);
    _ref.invalidate(currentEmpresaProvider);
  }

  Future<void> saveCustos(CostConfig config) async {
    final atual = await _ref.read(costConfigRepositoryProvider).get();
    await _ref
        .read(costConfigRepositoryProvider)
        .update(atual.id!, config);
    _ref.invalidate(costConfigProvider);
  }

  Future<void> addMember({
    required String nome,
    required String email,
    required String password,
    required Papel papel,
  }) async {
    await _ref.read(teamRepositoryProvider).addMember(
          nome: nome,
          email: email,
          password: password,
          papel: papel,
        );
    _ref.invalidate(teamMembersProvider);
  }

  Future<void> changeRole(String memberId, Papel papel) async {
    await _ref.read(teamRepositoryProvider).changeRole(memberId, papel);
    _ref.invalidate(teamMembersProvider);
  }
}
