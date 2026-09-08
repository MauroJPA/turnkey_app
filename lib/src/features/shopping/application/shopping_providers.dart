import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../inventory/application/inventory_providers.dart';
import '../data/shopping_repository.dart';
import '../domain/shopping_item.dart';

final shoppingListProvider =
    FutureProvider.autoDispose<List<ShoppingItem>>((ref) {
  return ref.watch(shoppingRepositoryProvider).list();
});

final shoppingActionsProvider =
    Provider<ShoppingActions>(ShoppingActions.new);

class ShoppingActions {
  ShoppingActions(this._ref);
  final Ref _ref;

  ShoppingRepository get _repo => _ref.read(shoppingRepositoryProvider);

  void _refresh({bool stock = false}) {
    _ref.invalidate(shoppingListProvider);
    if (stock) {
      _ref.invalidate(stockListProvider);
      _ref.invalidate(movimentosProvider);
    }
  }

  Future<void> adicionarManual({
    required String descricao,
    String fornecedor = '',
    double comprarG = 0,
  }) async {
    await _repo.addManual(
      descricao: descricao,
      fornecedor: fornecedor,
      comprarG: comprarG,
    );
    _refresh();
  }

  Future<void> editarComprar(String id, double gramas) async {
    await _repo.updateComprar(id, gramas);
    _refresh();
  }

  Future<void> definirComprado(ShoppingItem item, bool comprado) async {
    await _repo.definirComprado(item, comprado);
    _refresh(stock: true);
  }

  Future<void> remover(String id) async {
    await _repo.remover(id);
    _refresh();
  }

  Future<int> limparComprados() async {
    final n = await _repo.limparComprados();
    _refresh();
    return n;
  }

  Future<({int removidas, int recalculadas})> reorganizar() async {
    final r = await _repo.reorganizar();
    _refresh(stock: true);
    return r;
  }
}
