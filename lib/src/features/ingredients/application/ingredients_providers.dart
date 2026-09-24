import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nutrition/nutrition.dart';
import '../data/ingredient_repository.dart';
import '../domain/auto_insa.dart';
import '../domain/ingredient.dart';
import '../domain/nutri_ingresso.dart';

/// Lista de ingredientes ativos (ou da lixeira, se [trash] for `true`).
final ingredientsListProvider =
    FutureProvider.autoDispose.family<List<Ingrediente>, bool>((ref, trash) {
  return ref.watch(ingredientRepositoryProvider).list(trash: trash);
});

/// Ações de mutação. Chamam o repositório e invalidam as listas.
final ingredientActionsProvider = Provider<IngredientActions>((ref) {
  return IngredientActions(ref);
});

class IngredientActions {
  IngredientActions(this._ref);
  final Ref _ref;

  IngredientRepository get _repo =>
      _ref.read(ingredientRepositoryProvider);

  void _refresh() {
    _ref.invalidate(ingredientsListProvider);
  }

  Future<Ingrediente> create(
    IngredienteInput input, {
    NutriIngresso? nutri,
  }) async {
    var criado = await _repo.create(input);
    if (nutri != null && nutri.temDados) {
      criado = await _repo.definirNutricao(
        criado.id,
        nutri: nutri.nutri,
        base: nutri.base,
        alergenios: nutri.alergenios,
        alergeniosTracos: const [],
      );
    }
    _refresh();
    return criado;
  }

  Future<void> update(String id, IngredienteInput input) async {
    await _repo.update(id, input);
    _refresh();
  }

  Future<void> duplicate(Ingrediente src) async {
    await _repo.duplicate(src);
    _refresh();
  }

  Future<void> moveToTrash(String id) async {
    await _repo.setDeleted(id, deletado: true);
    _refresh();
  }

  Future<void> restore(String id) async {
    await _repo.setDeleted(id, deletado: false);
    _refresh();
  }

  Future<void> deleteForever(String id) async {
    await _repo.hardDelete(id);
    _refresh();
  }

  /// Lê um rótulo por IA e devolve o ingrediente já atualizado.
  Future<Ingrediente> analisarRotulo(
    String id, {
    required List<int> bytes,
    required String nome,
  }) async {
    final ing = await _repo.analisarRotulo(id, bytes: bytes, nome: nome);
    _refresh();
    return ing;
  }

  /// Anexa/substitui a foto da tabela nutricional (sem IA).
  Future<Ingrediente> anexarFotoNutri(
    String id, {
    required List<int> bytes,
    required String nome,
  }) async {
    final ing = await _repo.anexarFotoNutri(id, bytes: bytes, nome: nome);
    _refresh();
    return ing;
  }

  /// Remove a foto da tabela nutricional.
  Future<Ingrediente> removerFotoNutri(String id) async {
    final ing = await _repo.removerFotoNutri(id);
    _refresh();
    return ing;
  }

  /// Corre o emparelhamento automático com a INSA. Devolve o resumo
  /// (quantos preenchidos, quais ficaram por rever).
  Future<ResumoAutoInsa> autoPreencherInsa({List<String>? ids}) async {
    final r = await _repo.autoInsa(ids: ids);
    _refresh();
    return r;
  }

  /// Só devolve os candidatos INSA para um ingrediente (não grava).
  Future<ResumoAutoInsa> sugestoesInsa(String id) =>
      _repo.autoInsa(ids: [id], dryRun: true);

  Future<void> definirNutricao(
    String id, {
    required Nutrientes nutri,
    String base = '100g',
    double densidade = 1,
    required List<String> alergenios,
    required List<String> alergeniosTracos,
    String origem = 'manual',
  }) async {
    await _repo.definirNutricao(
      id,
      nutri: nutri,
      base: base,
      densidade: densidade,
      alergenios: alergenios,
      alergeniosTracos: alergeniosTracos,
      origem: origem,
    );
    _refresh();
  }
}
