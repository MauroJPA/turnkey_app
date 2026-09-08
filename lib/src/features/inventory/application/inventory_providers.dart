import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/inventory_repository.dart';
import '../domain/stock_item.dart';

final stockListProvider =
    FutureProvider.autoDispose<List<StockItem>>((ref) {
  return ref.watch(inventoryRepositoryProvider).list();
});

typedef ItemRef = ({String? ingredienteId, String? fichaId});

final movimentosProvider =
    FutureProvider.autoDispose.family<List<MovimentoStock>, ItemRef>(
  (ref, key) => ref.watch(inventoryRepositoryProvider).movimentos(
        ingredienteId: key.ingredienteId,
        fichaId: key.fichaId,
      ),
);

final inventoryActionsProvider = Provider<InventoryActions>(InventoryActions.new);

class InventoryActions {
  InventoryActions(this._ref);
  final Ref _ref;

  Future<void> ajustar({
    required StockItem item,
    double delta = 0,
    MotivoMovimento motivo = MotivoMovimento.ajuste,
    String? notas,
    double? minimo,
    String? localizacao,
  }) async {
    await _ref.read(inventoryRepositoryProvider).ajustar(
          ingredienteId:
              item.tipo == StockTipo.ingrediente ? item.id : null,
          fichaId: item.tipo == StockTipo.ficha ? item.id : null,
          delta: delta,
          motivo: motivo,
          notas: notas,
          minimo: minimo,
          localizacao: localizacao,
        );
    _ref.invalidate(stockListProvider);
    _ref.invalidate(movimentosProvider);
  }
}
