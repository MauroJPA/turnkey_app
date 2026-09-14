import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/equipamentos_repository.dart';
import '../domain/equipamento.dart';

final equipamentosListProvider =
    FutureProvider.autoDispose.family<List<Equipamento>, bool>(
  (ref, arquivados) => ref
      .watch(equipamentosRepositoryProvider)
      .list(incluirArquivados: arquivados),
);

final equipamentosActionsProvider =
    Provider<EquipamentosActions>(EquipamentosActions.new);

class EquipamentosActions {
  EquipamentosActions(this._ref);
  final Ref _ref;

  void _refresh() => _ref.invalidate(equipamentosListProvider);

  Future<void> create(EquipamentoInput input) async {
    await _ref.read(equipamentosRepositoryProvider).create(input);
    _refresh();
  }

  Future<void> update(String id, EquipamentoInput input) async {
    await _ref.read(equipamentosRepositoryProvider).update(id, input);
    _refresh();
  }

  Future<void> arquivar(String id) async {
    await _ref
        .read(equipamentosRepositoryProvider)
        .setArquivado(id, arquivado: true);
    _refresh();
  }

  Future<void> restaurar(String id) async {
    await _ref
        .read(equipamentosRepositoryProvider)
        .setArquivado(id, arquivado: false);
    _refresh();
  }

  Future<void> apagar(String id) async {
    await _ref.read(equipamentosRepositoryProvider).hardDelete(id);
    _refresh();
  }
}
