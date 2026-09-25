import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ingredients/application/ingredients_providers.dart';
import '../../ingredients/data/ingredient_product_repository.dart';
import '../../mise_en_place/data/mep_repository.dart';
import '../domain/lista_ingredientes.dart';

/// Lista de ingredientes de um produto final (ficha técnica): os ingredientes
/// crus de toda a árvore (massa, recheios, coberturas…), por ordem decrescente
/// de peso, com os alergénios de cada um.
final produtoIngredientesProvider = FutureProvider.autoDispose
    .family<ListaIngredientes, String>((ref, fichaId) async {
      // 1 unidade do produto: os pesos só servem para ordenar.
      final plano = await ref
          .watch(mepRepositoryProvider)
          .planoFicha(fichaId, 1);
      final todos = await ref.watch(ingredientsListProvider(false).future);
      final porId = {for (final i in todos) i.id: i};
      final produtos = {
        for (final p in await ref.watch(produtosIngredienteProvider.future))
          p.id: p,
      };
      return ListaIngredientes.de([
        for (final c in plano.comprar)
          IngredienteRotulo(
            nome: c.nome,
            gramas: c.gramas,
            // os do genérico + os dos produtos que as receitas fixam
            alergenios: {
              ...?porId[c.ingredienteId]?.alergenios,
              for (final pid in c.produtoIds) ...?produtos[pid]?.alergenios,
            }.toList(),
            marca: porId[c.ingredienteId]?.marca ?? '',
            nomeRotulo: porId[c.ingredienteId]?.nomeRotulo ?? '',
          ),
      ]);
    });
