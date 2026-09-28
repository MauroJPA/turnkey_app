import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/consumables/application/consumivel_providers.dart';
import '../../features/ingredients/application/ingredients_providers.dart';
import '../../features/ingredients/data/ingredient_product_repository.dart';
import '../../features/packaging/application/embalagem_providers.dart';
import '../pocketbase/pb_client.dart';

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

/// Tipo de valor a juntar: `marca` (produtos de compra + consumíveis) ou
/// `fornecedor` (também embalagens).
enum TipoCatalogo {
  marca,
  fornecedor;

  String get api => name;
  String get label => switch (this) {
    TipoCatalogo.marca => 'Marca',
    TipoCatalogo.fornecedor => 'Fornecedor',
  };
}

final marcasFornecedoresActionsProvider = Provider<MarcasFornecedoresActions>(
  MarcasFornecedoresActions.new,
);

/// Junta variantes do mesmo nome de marca/fornecedor (ex.: "Recheio Cash &
/// Carry, S.A." e "Recheio Cash & Carry, SA") num só, em todos os produtos de
/// compra/consumíveis/embalagens que os têm — só proprietário/administrador.
class MarcasFornecedoresActions {
  MarcasFornecedoresActions(this._ref);
  final Ref _ref;

  /// Devolve quantos registos foram alterados.
  Future<int> juntar({
    required TipoCatalogo tipo,
    required List<String> valores,
    required String destino,
  }) async {
    final pb = _ref.read(pbProvider);
    final res = await pb.send(
      '/api/gc_turnkey/marcas-fornecedores/juntar',
      method: 'POST',
      body: {'tipo': tipo.api, 'valores': valores, 'destino': destino},
    );
    final m = res as Map;
    _ref.invalidate(produtosIngredienteProvider);
    _ref.invalidate(consumiveisListProvider);
    _ref.invalidate(embalagensListProvider);
    _ref.invalidate(ingredientsListProvider);
    return (m['alterados'] as num?)?.toInt() ?? 0;
  }
}
