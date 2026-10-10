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

  /// Peso do produto: as embalagens (peças/kits) não pesam.
  // embalagens e artigos de revenda (unidades) não pesam
  double get pesoTotal => itens
      .where((i) => !i.isEmbalagem && i.consumivelId == null)
      .fold(0, (s, i) => s + i.quantidadeG);

  /// Custo do produto na loja: tudo menos a embalagem só para plataformas.
  double get custoPreview => itens
      .where((i) => i.slot != SlotFicha.embalagemPlataforma)
      .fold(0, (s, i) => s + i.custoLinha);

  /// Quanto desse custo é embalagem (o bloco "Embalagem").
  double get custoEmbalagem => itens
      .where((i) => i.slot == SlotFicha.embalagem)
      .fold(0, (s, i) => s + i.custoLinha);

  /// O que é matéria-prima (ingredientes, massas, recheios, coberturas…).
  double get custoMateriaPrima => custoPreview - custoEmbalagem;

  /// Embalagem extra só para as plataformas (sacos de entrega, selos…).
  double get custoEmbalagemPlataforma => itens
      .where((i) => i.slot == SlotFicha.embalagemPlataforma)
      .fold(0, (s, i) => s + i.custoLinha);

  bool get temEmbalagemPlataforma =>
      itens.any((i) => i.slot == SlotFicha.embalagemPlataforma);

  /// Custo do produto quando vai para uma plataforma.
  double get custoPlataforma => custoPreview + custoEmbalagemPlataforma;

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

  Future<FichaTecnica> create(FichaInput input, {bool revenda = false}) async {
    final f = await _repo.create(input, revenda: revenda);
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

  Future<void> setIva(String id, double? pct) async {
    await _repo.setIva(id, pct);
    _refreshDetail(id);
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
    String? consumivelId,
    required double quantidadeG,
  }) async {
    await _items.add(
      fichaId: fichaId,
      slot: slot,
      ingredienteId: ingredienteId,
      receitaId: receitaId,
      embalagemId: embalagemId,
      kitId: kitId,
      consumivelId: consumivelId,
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
