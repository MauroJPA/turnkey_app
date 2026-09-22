import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/configuracoes_encomendas_repository.dart';
import '../domain/configuracao_encomendas.dart';

final configuracoesEncomendasActionsProvider =
    Provider<ConfiguracoesEncomendasActions>(ConfiguracoesEncomendasActions.new);

class ConfiguracoesEncomendasActions {
  ConfiguracoesEncomendasActions(this._ref);
  final Ref _ref;

  Future<void> salvar(
    String existingId,
    ConfiguracaoEncomendasInput input,
  ) async {
    await _ref
        .read(configuracoesEncomendasRepositoryProvider)
        .salvar(existingId, input);
    _ref.invalidate(configuracaoEncomendasProvider);
  }
}
