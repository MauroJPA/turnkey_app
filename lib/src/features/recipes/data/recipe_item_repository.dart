import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../domain/recipe_item.dart';

final recipeItemRepositoryProvider = Provider<RecipeItemRepository>((ref) {
  return RecipeItemRepository(ref.watch(pbProvider), requireEmpresaId(ref));
});

class RecipeItemRepository {
  RecipeItemRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String _empresaId;

  RecordService get _c => _pb.collection('itens_receita');

  Future<List<ItemReceita>> listForRecipe(String recipeId) async {
    final recs = await _c.getFullList(
      filter: 'receita = "$recipeId"',
      expand: 'ingrediente,sub_receita',
      sort: 'created',
    );
    return recs.map(ItemReceita.fromRecord).toList();
  }

  Future<void> addIngrediente(
    String recipeId,
    String ingredienteId,
    double quantidadeG,
  ) {
    return _c.create(
      body: {
        'empresa': _empresaId,
        'receita': recipeId,
        'ingrediente': ingredienteId,
        'quantidade_g': quantidadeG,
      },
    );
  }

  Future<void> addSubReceita(
    String recipeId,
    String subReceitaId,
    double quantidadeG,
  ) {
    return _c.create(
      body: {
        'empresa': _empresaId,
        'receita': recipeId,
        'sub_receita': subReceitaId,
        'quantidade_g': quantidadeG,
      },
    );
  }

  /// Linha sem correspondência (importação): fica pendente até ser ligada.
  Future<void> addPendente(
    String recipeId,
    String nomeProvisorio,
    double quantidadeG,
  ) {
    return _c.create(
      body: {
        'empresa': _empresaId,
        'receita': recipeId,
        'nome_provisorio': nomeProvisorio,
        'quantidade_g': quantidadeG,
      },
    );
  }

  Future<void> setQuantidade(String itemId, double quantidadeG) =>
      _c.update(itemId, body: {'quantidade_g': quantidadeG});

  /// Liga um item pendente (importado sem correspondência) a um ingrediente
  /// ou sub-receita.
  Future<void> vincular(
    String itemId, {
    String? ingredienteId,
    String? subReceitaId,
  }) {
    return _c.update(
      itemId,
      body: {
        'ingrediente': ingredienteId ?? '',
        'sub_receita': subReceitaId ?? '',
        'nome_provisorio': '',
      },
    );
  }

  Future<void> remove(String itemId) => _c.delete(itemId);
}
