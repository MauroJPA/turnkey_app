import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../domain/colaborador.dart';

final colaboradoresRepositoryProvider = Provider<ColaboradoresRepository>((
  ref,
) {
  return ColaboradoresRepository(ref.watch(pbProvider), requireEmpresaId(ref));
});

/// Colaboradores e os seus cartões NFC (`colaboradores`).
class ColaboradoresRepository {
  ColaboradoresRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String _empresaId;

  RecordService get _c => _pb.collection('colaboradores');

  Future<List<Colaborador>> list({bool incluirArquivados = false}) async {
    final filtros = ['empresa = "$_empresaId"'];
    if (!incluirArquivados) filtros.add('arquivado != true');
    final recs = await _c.getFullList(
      filter: filtros.join(' && '),
      sort: 'ordem,nome',
    );
    return recs.map(Colaborador.fromRecord).toList();
  }

  Future<void> criar(String nome) => _c.create(
    body: {
      'empresa': _empresaId,
      'nome': nome.trim(),
      'nfc_uid': '',
      'arquivado': false,
    },
  );

  Future<void> renomear(String id, String nome) =>
      _c.update(id, body: {'nome': nome.trim()});

  /// Associa (ou, com vazio, tira) o cartão.
  Future<void> definirCartao(String id, String uid) =>
      _c.update(id, body: {'nfc_uid': normalizarUid(uid)});

  Future<void> arquivar(String id, {required bool arquivado}) =>
      _c.update(id, body: {'arquivado': arquivado});
}
