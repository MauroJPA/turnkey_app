import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tech_sheet_item_repository.dart';
import '../data/tech_sheet_repository.dart';
import '../domain/tech_sheet.dart';
import '../domain/tech_sheet_item.dart';

final fichasListProvider =
    FutureProvider.autoDispose.family<List<FichaTecnica>, bool>((ref, trash) {
  return ref.watch(techSheetRepositoryProvider).list(trash: trash);
});

class FichaDetail {
  FichaDetail({required this.ficha, required this.itens});

  final FichaTecnica ficha;
  final List<ItemFicha> itens;

  double get pesoTotal => itens.fold(0, (s, i) => s + i.quantidadeG);
  double get custoPreview => itens.fold(0, (s, i) => s + i.custoLinha);

  Map<SlotFicha, List<ItemFicha>> get porSlot =>
      groupBy(itens, (ItemFicha i) => i.slot);

  double percentagem(ItemFicha i) =>
      pesoTotal > 0 ? (i.quantidadeG / pesoTotal) * 100 : 0;
}

final fichaDetailProvider =
    FutureProvider.autoDispose.family<FichaDetail, String>((ref, id) async {
  final ficha = await ref.watch(techSheetRepositoryProvider).getById(id);
  final itens =
      await ref.watch(techSheetItemRepositoryProvider).listForFicha(id);
  return FichaDetail(ficha: ficha, itens: itens);
});

final fichaActionsProvider = Provider<FichaActions>(FichaActions.new);

class FichaActions {
  FichaActions(this._ref);
  final Ref _ref;

  TechSheetRepository get _repo => _ref.read(techSheetRepositoryProvider);
  TechSheetItemRepository get _items =>
      _ref.read(techSheetItemRepositoryProvider);

  void _refreshLists() => _ref.invalidate(fichasListProvider);
  void _refreshDetail(String id) {
    _ref.invalidate(fichaDetailProvider(id));
    _ref.invalidate(fichasListProvider);
  }

  Future<FichaTecnica> create(FichaInput input) async {
    final f = await _repo.create(input);
    _refreshLists();
    return f;
  }

  Future<void> update(String id, FichaInput input) async {
    await _repo.update(id, input);
    _refreshDetail(id);
  }

  Future<void> duplicate(String id) async {
    await _repo.duplicate(id);
    _refreshLists();
  }

  Future<void> moveToTrash(String id) async {
    await _repo.setDeleted(id, deletado: true);
    _refreshLists();
  }

  Future<void> restore(String id) async {
    await _repo.setDeleted(id, deletado: false);
    _refreshLists();
  }

  Future<void> setPrecoVenda(String id, double valor) async {
    await _repo.setPrecoVenda(id, valor);
    _refreshDetail(id);
  }

  Future<void> deleteForever(String id) async {
    await _repo.hardDelete(id);
    _refreshLists();
  }

  Future<void> addItem({
    required String fichaId,
    required SlotFicha slot,
    String? ingredienteId,
    String? receitaId,
    String? embalagemId,
    String? kitId,
    required double quantidadeG,
  }) async {
    await _items.add(
      fichaId: fichaId,
      slot: slot,
      ingredienteId: ingredienteId,
      receitaId: receitaId,
      embalagemId: embalagemId,
      kitId: kitId,
      quantidadeG: quantidadeG,
    );
    _refreshDetail(fichaId);
  }

  Future<void> setQuantidade(String fichaId, String itemId, double qtd) async {
    await _items.setQuantidade(itemId, qtd);
    _refreshDetail(fichaId);
  }

  Future<void> removeItem(String fichaId, String itemId) async {
    await _items.remove(itemId);
    _refreshDetail(fichaId);
  }
}
