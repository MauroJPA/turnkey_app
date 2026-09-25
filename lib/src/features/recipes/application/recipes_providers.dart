import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/recipe_item_repository.dart';
import '../data/recipe_repository.dart';
import '../domain/recipe.dart';
import '../domain/recipe_item.dart';

/// Lista de receitas ativas (ou da lixeira).
final recipesListProvider =
    FutureProvider.autoDispose.family<List<Receita>, bool>((ref, trash) {
  return ref.watch(recipeRepositoryProvider).list(trash: trash);
});

/// Receita + linhas + totais (pré-visualização; o custo definitivo vem do hook).
class RecipeDetail {
  RecipeDetail({required this.receita, required this.itens});

  final Receita receita;
  final List<ItemReceita> itens;

  double get pesoLinhas =>
      itens.fold(0, (s, i) => s + i.quantidadeG);

  double get pesoTotal => receita.rendimentoManual && receita.rendimentoEsperado > 0
      ? receita.rendimentoEsperado
      : pesoLinhas;

  double get custoPreview =>
      itens.fold(0, (s, i) => s + i.custoLinha);

  double get custoPorKg =>
      pesoTotal > 0 ? (custoPreview / pesoTotal) * 1000 : 0;

  bool get temPendencias => itens.any((i) => i.pendente);

  double percentagem(ItemReceita i) =>
      pesoLinhas > 0 ? (i.quantidadeG / pesoLinhas) * 100 : 0;
}

final recipeDetailProvider =
    FutureProvider.autoDispose.family<RecipeDetail, String>((ref, id) async {
  final receita = await ref.watch(recipeRepositoryProvider).getById(id);
  final itens =
      await ref.watch(recipeItemRepositoryProvider).listForRecipe(id);
  return RecipeDetail(receita: receita, itens: itens);
});

final recipeActionsProvider = Provider<RecipeActions>(RecipeActions.new);

class RecipeActions {
  RecipeActions(this._ref);
  final Ref _ref;

  RecipeRepository get _repo => _ref.read(recipeRepositoryProvider);
  RecipeItemRepository get _items => _ref.read(recipeItemRepositoryProvider);

  void _refreshLists() => _ref.invalidate(recipesListProvider);
  void _refreshDetail(String id) {
    _ref.invalidate(recipeDetailProvider(id));
    _ref.invalidate(recipesListProvider);
  }

  Future<Receita> create(RecipeInput input) async {
    final r = await _repo.create(input);
    _refreshLists();
    return r;
  }

  Future<void> update(String id, RecipeInput input) async {
    await _repo.update(id, input);
    _refreshDetail(id);
  }

  Future<void> setPublicar(String id, {required bool valor}) async {
    await _repo.setPublicar(id, valor: valor);
    _refreshDetail(id);
  }

  Future<void> setPerdaCozedura(String id, double pct) async {
    await _repo.setPerdaCozedura(id, pct);
    _refreshDetail(id);
  }

  Future<void> setProcedimento(String id, String procedimento) async {
    await _repo.setProcedimento(id, procedimento);
    _refreshDetail(id);
  }

  Future<void> adicionarImagens(
    String id,
    List<({String nome, List<int> bytes})> novas,
  ) async {
    await _repo.adicionarImagens(id, novas);
    _refreshDetail(id);
  }

  Future<void> removerImagem(String id, String nomeFicheiro) async {
    await _repo.removerImagem(id, nomeFicheiro);
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

  Future<void> deleteForever(String id) async {
    await _repo.hardDelete(id);
    _refreshLists();
  }

  Future<void> addIngrediente(
    String recipeId,
    String ingId,
    double qtd, {
    String? produtoId,
  }) async {
    await _items.addIngrediente(recipeId, ingId, qtd, produtoId: produtoId);
    _refreshDetail(recipeId);
  }

  /// Fixa (ou, com `null`, deixa de fixar) o produto de compra de uma linha.
  Future<void> setProduto(
    String recipeId,
    String itemId,
    String? produtoId,
  ) async {
    await _items.setProduto(itemId, produtoId);
    _refreshDetail(recipeId);
  }

  Future<void> addSubReceita(String recipeId, String subId, double qtd) async {
    await _items.addSubReceita(recipeId, subId, qtd);
    _refreshDetail(recipeId);
  }

  Future<void> setQuantidade(String recipeId, String itemId, double qtd) async {
    await _items.setQuantidade(itemId, qtd);
    _refreshDetail(recipeId);
  }

  Future<void> vincular(
    String recipeId,
    String itemId, {
    String? ingredienteId,
    String? subReceitaId,
  }) async {
    await _items.vincular(
      itemId,
      ingredienteId: ingredienteId,
      subReceitaId: subReceitaId,
    );
    _refreshDetail(recipeId);
  }

  Future<void> removeItem(String recipeId, String itemId) async {
    await _items.remove(itemId);
    _refreshDetail(recipeId);
  }
}
