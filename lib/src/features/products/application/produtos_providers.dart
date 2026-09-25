import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ingredients/application/ingredients_providers.dart';
import '../../mise_en_place/data/mep_repository.dart';
import '../domain/lista_ingredientes.dart';

/// Lista de ingredientes de um produto final (ficha técnica): os ingredientes
/// crus de toda a árvore (massa, recheios, coberturas…), por ordem decrescente
/// de peso, com os alergénios de cada um.
final produtoIngredientesProvider = FutureProvider.autoDispose
    .family<ListaIngredientes, String>((ref, fichaId) async {
  // 1 unidade do produto: os pesos só servem para ordenar.
  final plano = await ref.watch(mepRepositoryProvider).planoFicha(fichaId, 1);
  final todos = await ref.watch(ingredientsListProvider(false).future);
  final porId = {for (final i in todos) i.id: i};
  return ListaIngredientes.de([
    for (final c in plano.comprar)
      IngredienteRotulo(
        nome: c.nome,
        gramas: c.gramas,
        alergenios: porId[c.ingredienteId]?.alergenios ?? const [],
        marca: porId[c.ingredienteId]?.marca ?? '',
        nomeRotulo: porId[c.ingredienteId]?.nomeRotulo ?? '',
      ),
  ]);
});
