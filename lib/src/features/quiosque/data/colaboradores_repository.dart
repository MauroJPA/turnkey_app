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

  /// As linhas guardadas (pessoas sem conta e os cartões/estado da Equipa).
  Future<List<Colaborador>> linhas() async {
    final recs = await _c.getFullList(
      filter: 'empresa = "$_empresaId"',
      sort: 'ordem,nome',
    );
    return recs.map(Colaborador.fromRecord).toList();
  }

  /// Uma pessoa sem conta na app.
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

  /// Associa (ou, com vazio, tira) o cartão. Se a pessoa é da Equipa e ainda
  /// não tem linha, cria-a.
  Future<void> definirCartao(Colaborador c, String uid) {
    final u = normalizarUid(uid);
    if (c.virtual) return _criarLinhaDaConta(c, nfcUid: u);
    return _c.update(c.id, body: {'nfc_uid': u});
  }

  /// Esconde (ou volta a mostrar) a pessoa no quiosque.
  Future<void> arquivar(Colaborador c, {required bool arquivado}) {
    if (c.virtual) return _criarLinhaDaConta(c, arquivado: arquivado);
    return _c.update(c.id, body: {'arquivado': arquivado});
  }

  Future<void> _criarLinhaDaConta(
    Colaborador c, {
    String nfcUid = '',
    bool arquivado = false,
  }) => _c.create(
    body: {
      'empresa': _empresaId,
      'user': c.userId,
      'nome': c.nome,
      'nfc_uid': nfcUid,
      'arquivado': arquivado,
    },
  );
}
