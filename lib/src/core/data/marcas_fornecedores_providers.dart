import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/consumables/application/consumivel_providers.dart';
import '../../features/ingredients/data/ingredient_product_repository.dart';
import '../../features/packaging/application/embalagem_providers.dart';

List<String> _ordenados(Iterable<String> valores) {
  final set = <String>{
    for (final v in valores)
      if (v.trim().isNotEmpty) v.trim(),
  };
  final lista = set.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return lista;
}

/// Marcas já usadas na empresa (produtos de compra de ingredientes +
/// consumíveis), para sugerir ao escrever numa nova — sem obrigar a repetir
/// texto já escrito noutro sítio.
final marcasConhecidasProvider = Provider.autoDispose<List<String>>((ref) {
  final produtos =
      ref.watch(produtosIngredienteProvider).valueOrNull ?? const [];
  final consumiveis =
      ref.watch(consumiveisListProvider).valueOrNull ?? const [];
  return _ordenados([
    for (final p in produtos) p.marca,
    for (final c in consumiveis) c.marca,
  ]);
});

/// Fornecedores já usados na empresa (produtos de compra, consumíveis e
/// embalagens), para sugerir ao escrever um novo.
final fornecedoresConhecidosProvider = Provider.autoDispose<List<String>>((
  ref,
) {
  final produtos =
      ref.watch(produtosIngredienteProvider).valueOrNull ?? const [];
  final consumiveis =
      ref.watch(consumiveisListProvider).valueOrNull ?? const [];
  final embalagens = ref.watch(embalagensListProvider).valueOrNull ?? const [];
  return _ordenados([
    for (final p in produtos) p.fornecedor,
    for (final c in consumiveis) c.fornecedor,
    for (final e in embalagens) e.fornecedor,
  ]);
});
