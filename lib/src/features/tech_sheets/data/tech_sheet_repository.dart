import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../domain/tech_sheet.dart';

final techSheetRepositoryProvider = Provider<TechSheetRepository>((ref) {
  return TechSheetRepository(ref.watch(pbProvider), requireEmpresaId(ref));
});

class TechSheetRepository {
  TechSheetRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String _empresaId;

  RecordService get _c => _pb.collection('fichas_tecnicas');
  RecordService get _itens => _pb.collection('itens_ficha');

  Future<List<FichaTecnica>> list({bool trash = false}) async {
    final recs = await _c.getFullList(
      filter: 'empresa = "$_empresaId" && deletado = $trash',
      sort: 'nome',
    );
    return recs.map(FichaTecnica.fromRecord).toList();
  }

  Future<FichaTecnica> getById(String id) async =>
      FichaTecnica.fromRecord(await _c.getOne(id));

  Future<FichaTecnica> create(FichaInput input) async {
    final rec = await _c.create(
      body: {...input.toBody(), 'empresa': _empresaId, 'deletado': false},
    );
    return FichaTecnica.fromRecord(rec);
  }

  Future<FichaTecnica> update(String id, FichaInput input) async =>
      FichaTecnica.fromRecord(await _c.update(id, body: input.toBody()));

  Future<void> setDeleted(String id, {required bool deletado}) =>
      _c.update(id, body: {'deletado': deletado});

  Future<void> setPrecoVenda(String id, double valor) =>
      _c.update(id, body: {'preco_venda': valor});

  Future<void> hardDelete(String id) => _c.delete(id);

  Future<FichaTecnica> duplicate(String id) async {
    final src = await _c.getOne(id);
    final nova = await _c.create(
      body: {
        'empresa': _empresaId,
        'nome': '${src.getStringValue('nome')} (cópia)',
        'categoria': src.getStringValue('categoria'),
        'deletado': false,
      },
    );
    final itens = await _itens.getFullList(filter: 'ficha = "$id"');
    for (final it in itens) {
      await _itens.create(
        body: {
          'empresa': _empresaId,
          'ficha': nova.id,
          'ingrediente': it.getStringValue('ingrediente'),
          'receita': it.getStringValue('receita'),
          'embalagem': it.getStringValue('embalagem'),
          'kit': it.getStringValue('kit'),
          'quantidade_g': it.getDoubleValue('quantidade_g'),
          'slot': it.getStringValue('slot'),
        },
      );
    }
    return FichaTecnica.fromRecord(nova);
  }
}
