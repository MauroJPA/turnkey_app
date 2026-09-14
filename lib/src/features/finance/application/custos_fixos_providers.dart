import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/custos_fixos_repository.dart';
import '../domain/custo_fixo.dart';

final custosFixosListProvider =
    FutureProvider.autoDispose.family<List<CustoFixo>, bool>((ref, arquivados) {
  return ref.watch(custosFixosRepositoryProvider).list(
        incluirArquivados: arquivados,
      );
});

final custosFixosActionsProvider =
    Provider<CustosFixosActions>(CustosFixosActions.new);

class CustosFixosActions {
  CustosFixosActions(this._ref);
  final Ref _ref;

  void _refresh() {
    _ref.invalidate(custosFixosListProvider);
  }

  Future<void> create(CustoFixoInput input) async {
    await _ref.read(custosFixosRepositoryProvider).create(input);
    _refresh();
  }

  Future<void> update(String id, CustoFixoInput input) async {
    await _ref.read(custosFixosRepositoryProvider).update(id, input);
    _refresh();
  }

  Future<void> arquivar(String id) async {
    await _ref
        .read(custosFixosRepositoryProvider)
        .setArquivado(id, arquivado: true);
    _refresh();
  }

  Future<void> restaurar(String id) async {
    await _ref
        .read(custosFixosRepositoryProvider)
        .setArquivado(id, arquivado: false);
    _refresh();
  }

  Future<void> apagar(String id) async {
    await _ref.read(custosFixosRepositoryProvider).hardDelete(id);
    _refresh();
  }
}
