import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../inventory/domain/stock_item.dart';
import '../domain/shopping_item.dart';

final shoppingRepositoryProvider = Provider<ShoppingRepository>((ref) {
  return ShoppingRepository(
    ref.watch(pbProvider),
    requireEmpresaId(ref),
    ref.watch(inventoryRepositoryProvider),
  );
});

class ShoppingRepository {
  ShoppingRepository(this._pb, this._empresaId, this._inventory);

  final PocketBase _pb;
  final String _empresaId;
  final InventoryRepository _inventory;

  RecordService get _c => _pb.collection('lista_compras');

  Future<List<ShoppingItem>> list() async {
    final recs = await _c.getFullList(
      filter: 'empresa = "$_empresaId"',
      sort: 'comprado,fornecedor,descricao',
    );
    return recs.map(ShoppingItem.fromRecord).toList();
  }

  Future<void> addManual({
    required String descricao,
    String fornecedor = '',
    double comprarG = 0,
  }) async {
    await _c.create(body: {
      'empresa': _empresaId,
      'descricao': descricao,
      'fornecedor': fornecedor,
      'quantidade_necessaria_g': comprarG,
      'quantidade_comprar_g': comprarG,
      'comprado': false,
    });
  }

  Future<void> updateComprar(String id, double gramas) async {
    await _c.update(id, body: {'quantidade_comprar_g': gramas});
  }

  /// Marca/desmarca como comprado. Ao marcar, entra no inventário
  /// (`+comprarG`, motivo `compra`); ao desmarcar, reverte (`-comprarG`,
  /// motivo `ajuste`). Itens manuais sem ingrediente não mexem no stock.
  Future<void> definirComprado(ShoppingItem item, bool comprado) async {
    if (comprado == item.comprado) return;
    if (item.ingredienteId != null && item.comprarG > 0) {
      await _inventory.ajustar(
        ingredienteId: item.ingredienteId,
        delta: comprado ? item.comprarG : -item.comprarG,
        motivo: comprado ? MotivoMovimento.compra : MotivoMovimento.ajuste,
        notas: comprado
            ? 'Lista de compras'
            : 'Correção — desmarcado da lista de compras',
      );
    }
    await _c.update(item.id, body: {'comprado': comprado});
  }

  Future<void> remover(String id) => _c.delete(id);

  Future<int> limparComprados() async {
    final recs = await _c.getFullList(
      filter: 'empresa = "$_empresaId" && comprado = true',
    );
    for (final r in recs) {
      await _c.delete(r.id);
    }
    return recs.length;
  }

  /// Reorganiza a lista: apaga as linhas já compradas (o stock delas já entrou
  /// ao dar o visto) e volta a gerar as linhas de cada produção envolvida
  /// contra o stock atual. Devolve o nº de linhas recalculadas.
  Future<({int removidas, int recalculadas})> reorganizar() async {
    final todas = await _c.getFullList(filter: 'empresa = "$_empresaId"');

    var removidas = 0;
    for (final r in todas.where((r) => r.getBoolValue('comprado'))) {
      await _c.delete(r.id);
      removidas++;
    }

    final producoes = <String>{
      for (final r in todas)
        if (!r.getBoolValue('comprado'))
          if (r.getStringValue('producao').isNotEmpty)
            r.getStringValue('producao'),
    };

    var recalculadas = 0;
    for (final pid in producoes) {
      final res = await _pb.send(
        '/api/turnkey/producoes/$pid/lista-compras',
        method: 'POST',
      );
      recalculadas += ((res as Map)['linhas'] as num?)?.toInt() ?? 0;
    }
    return (removidas: removidas, recalculadas: recalculadas);
  }
}
