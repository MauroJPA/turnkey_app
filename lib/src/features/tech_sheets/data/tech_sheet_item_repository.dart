import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../domain/tech_sheet.dart';
import '../domain/tech_sheet_item.dart';

final techSheetItemRepositoryProvider =
    Provider<TechSheetItemRepository>((ref) {
  return TechSheetItemRepository(ref.watch(pbProvider), requireEmpresaId(ref));
});

class TechSheetItemRepository {
  TechSheetItemRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String _empresaId;

  RecordService get _c => _pb.collection('itens_ficha');

  Future<List<ItemFicha>> listForFicha(String fichaId) async {
    final recs = await _c.getFullList(
      filter: 'ficha = "$fichaId"',
      expand: 'ingrediente,receita,embalagem,kit',
      sort: 'created',
    );
    return recs.map(ItemFicha.fromRecord).toList();
  }

  Future<void> add({
    required String fichaId,
    required SlotFicha slot,
    String? ingredienteId,
    String? receitaId,
    String? embalagemId,
    String? kitId,
    required double quantidadeG,
  }) {
    return _c.create(
      body: {
        'empresa': _empresaId,
        'ficha': fichaId,
        'slot': slot.api,
        if (ingredienteId != null) 'ingrediente': ingredienteId,
        if (receitaId != null) 'receita': receitaId,
        if (embalagemId != null) 'embalagem': embalagemId,
        if (kitId != null) 'kit': kitId,
        'quantidade_g': quantidadeG,
      },
    );
  }

  Future<void> setQuantidade(String itemId, double quantidadeG) =>
      _c.update(itemId, body: {'quantidade_g': quantidadeG});

  Future<void> remove(String itemId) => _c.delete(itemId);
}
