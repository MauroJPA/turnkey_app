import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../domain/embalagem_kit.dart';

final embalagemKitRepositoryProvider = Provider<EmbalagemKitRepository>((ref) {
  return EmbalagemKitRepository(ref.watch(pbProvider), requireEmpresaId(ref));
});

class EmbalagemKitRepository {
  EmbalagemKitRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String _empresaId;

  RecordService get _k => _pb.collection('embalagem_kits');
  RecordService get _ki => _pb.collection('embalagem_kit_itens');

  Future<List<EmbalagemKit>> list({bool trash = false}) async {
    final recs = await _k.getFullList(
      filter: 'empresa = "$_empresaId" && deletado = $trash',
      sort: 'nome',
    );
    return recs.map(EmbalagemKit.fromRecord).toList();
  }

  Future<List<EmbalagemKitItem>> itens(String kitId) async {
    final recs = await _ki.getFullList(
      filter: 'kit = "$kitId"',
      expand: 'embalagem',
      sort: 'created',
    );
    return recs.map(EmbalagemKitItem.fromRecord).toList();
  }

  Future<EmbalagemKit> create(EmbalagemKitInput input) async {
    final rec = await _k.create(
      body: {...input.toBody(), 'empresa': _empresaId},
    );
    return EmbalagemKit.fromRecord(rec);
  }

  Future<EmbalagemKit> update(String id, EmbalagemKitInput input) async =>
      EmbalagemKit.fromRecord(await _k.update(id, body: input.toBody()));

  Future<void> setDeleted(String id, {required bool deletado}) =>
      _k.update(id, body: {'deletado': deletado});

  Future<void> addItem(
    String kitId,
    String embalagemId,
    double quantidade,
  ) =>
      _ki.create(body: {
        'empresa': _empresaId,
        'kit': kitId,
        'embalagem': embalagemId,
        'quantidade': quantidade,
      });

  Future<void> setItemQuantidade(String itemId, double quantidade) =>
      _ki.update(itemId, body: {'quantidade': quantidade});

  Future<void> removeItem(String itemId) => _ki.delete(itemId);
}
