import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../domain/cookie_format.dart';

final cookieFormatRepositoryProvider = Provider<CookieFormatRepository>((ref) {
  return CookieFormatRepository(ref.watch(pbProvider), requireEmpresaId(ref));
});

class CookieFormatRepository {
  CookieFormatRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String _empresaId;

  RecordService get _c => _pb.collection('formatos_cookie');

  Future<List<FormatoCookie>> list({bool apenasAtivos = false}) async {
    final recs = await _c.getFullList(
      filter: apenasAtivos
          ? 'empresa = "$_empresaId" && ativo = true'
          : 'empresa = "$_empresaId"',
      sort: 'ordem,nome',
    );
    return recs.map(FormatoCookie.fromRecord).toList();
  }

  Future<FormatoCookie> create(FormatoInput input) async {
    final r = await _c.create(
      body: {...input.toBody(), 'empresa': _empresaId},
    );
    return FormatoCookie.fromRecord(r);
  }

  Future<FormatoCookie> update(String id, FormatoInput input) async =>
      FormatoCookie.fromRecord(await _c.update(id, body: input.toBody()));

  Future<void> delete(String id) => _c.delete(id);

  /// Quantas fichas técnicas usam este formato.
  Future<int> fichasQueUsam(String id) async {
    final r = await _pb
        .collection('fichas_tecnicas')
        .getList(perPage: 1, filter: 'formato = "$id"');
    return r.totalItems;
  }
}
