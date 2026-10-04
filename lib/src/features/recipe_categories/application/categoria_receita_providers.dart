import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../recipes/application/recipes_providers.dart';
import '../../recipes/data/recipe_repository.dart';
import '../domain/categoria_receita.dart';

/// As categorias para escolher numa receita: as sugeridas mais as que as
/// receitas já usam (uma categoria sem receitas desaparece sozinha).
final categoriasReceitaAtivasProvider =
    FutureProvider.autoDispose<List<CategoriaReceita>>((ref) async {
      final receitas = await ref.watch(recipesListProvider(false).future);
      return [
        for (final n in categoriasDisponiveis(receitas.map((r) => r.categoria)))
          CategoriaReceita(nome: n),
      ];
    });

/// Muda o nome de uma categoria em todas as receitas que a usam.
Future<void> renomearCategoriaReceita(
  WidgetRef ref, {
  required String de,
  required String para,
}) async {
  await ref.read(recipeRepositoryProvider).renomearCategoria(de, para);
  ref.invalidate(recipesListProvider);
  ref.invalidate(categoriasReceitaAtivasProvider);
}
