import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/inventory_repository.dart';
import '../domain/stock_item.dart';

final stockListProvider =
    FutureProvider.autoDispose<List<StockItem>>((ref) {
  return ref.watch(inventoryRepositoryProvider).list();
});

typedef ItemRef = ({String? ingredienteId, String? fichaId, String? descricao});

final movimentosProvider =
    FutureProvider.autoDispose.family<List<MovimentoStock>, ItemRef>(
  (ref, key) => ref.watch(inventoryRepositoryProvider).movimentos(
        ingredienteId: key.ingredienteId,
        fichaId: key.fichaId,
        descricao: key.descricao,
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
    bool? favorito,
  }) async {
    await _ref.read(inventoryRepositoryProvider).ajustar(
          ingredienteId:
              item.tipo == StockTipo.ingrediente ? item.id : null,
          fichaId: item.tipo == StockTipo.ficha ? item.id : null,
          descricao: item.tipo == StockTipo.livre ? item.id : null,
          delta: delta,
          motivo: motivo,
          notas: notas,
          minimo: minimo,
          localizacao: localizacao,
          favorito: favorito,
        );
    _ref.invalidate(stockListProvider);
    _ref.invalidate(movimentosProvider);
  }

  /// Marca/desmarca um item como favorito.
  Future<void> alternarFavorito(StockItem item) async {
    await _ref.read(inventoryRepositoryProvider).ajustar(
          ingredienteId:
              item.tipo == StockTipo.ingrediente ? item.id : null,
          fichaId: item.tipo == StockTipo.ficha ? item.id : null,
          descricao: item.tipo == StockTipo.livre ? item.id : null,
          favorito: !item.favorito,
        );
    _ref.invalidate(stockListProvider);
  }

  /// Cria (ou atualiza) um item livre no inventário.
  Future<void> criarItemLivre({
    required String descricao,
    required String unidade,
    String categoria = '',
    double quantidadeInicial = 0,
    double? minimo,
    String? localizacao,
  }) async {
    await _ref.read(inventoryRepositoryProvider).ajustar(
          descricao: descricao,
          unidade: unidade,
          categoria: categoria.isEmpty ? null : categoria,
          delta: quantidadeInicial,
          motivo: MotivoMovimento.ajuste,
          minimo: minimo,
          localizacao: localizacao,
        );
    _ref.invalidate(stockListProvider);
  }
}
