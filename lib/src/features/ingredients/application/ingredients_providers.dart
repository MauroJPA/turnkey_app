import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ingredient_repository.dart';
import '../domain/ingredient.dart';

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

  Future<void> create(IngredienteInput input) async {
    await _repo.create(input);
    _refresh();
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
}
