import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../domain/embalagem.dart';

final embalagemRepositoryProvider = Provider<EmbalagemRepository>((ref) {
  return EmbalagemRepository(ref.watch(pbProvider), requireEmpresaId(ref));
});

class EmbalagemRepository {
  EmbalagemRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String _empresaId;

  RecordService get _c => _pb.collection('embalagens');

  Future<List<Embalagem>> list({bool trash = false}) async {
    final recs = await _c.getFullList(
      filter: 'empresa = "$_empresaId" && deletado = $trash',
      sort: 'nome',
    );
    return recs.map(Embalagem.fromRecord).toList();
  }

  Future<Embalagem> create(EmbalagemInput input) async {
    final rec = await _c.create(
      body: {...input.toBody(), 'empresa': _empresaId, 'deletado': false},
    );
    return Embalagem.fromRecord(rec);
  }

  Future<Embalagem> update(String id, EmbalagemInput input) async =>
      Embalagem.fromRecord(await _c.update(id, body: input.toBody()));

  Future<void> setDeleted(String id, {required bool deletado}) =>
      _c.update(id, body: {'deletado': deletado});
}
