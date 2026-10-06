import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ingredients/application/ingredients_providers.dart';
import '../../ingredients/data/ingredient_product_repository.dart';
import '../domain/comparar_precos.dart';

/// Ingredientes que se podem comprar de mais de uma forma (marca/fornecedor),
/// comparados por preço ao kg/litro/unidade; os que poupam mais primeiro.
final comparacoesPrecoProvider =
    FutureProvider.autoDispose<List<ComparacaoIngrediente>>((ref) async {
      final ingredientes = await ref.watch(
        ingredientsListProvider(false).future,
      );
      final produtos = await ref.watch(produtosIngredienteProvider.future);
      return compararPrecos(ingredientes: ingredientes, produtos: produtos);
    });

/// Quantos ingredientes poupavam a trocar de marca/fornecedor (para o selo).
final poupancasPossiveisProvider = Provider.autoDispose<int>((ref) {
  final lista = ref.watch(comparacoesPrecoProvider).valueOrNull ?? const [];
  return lista.where((c) => c.temPoupanca).length;
});
