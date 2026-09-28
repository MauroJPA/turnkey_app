import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../domain/nota_pagina.dart';

final notaPaginaRepositoryProvider = Provider<NotaPaginaRepository>((ref) {
  return NotaPaginaRepository(ref.watch(pbProvider), requireEmpresaId(ref));
});

class NotaPaginaRepository {
  NotaPaginaRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String _empresaId;

  RecordService get _c => _pb.collection('notas_pagina');

  /// Notas desta página (empresa isolada pela regra da coleção), mais
  /// recentes primeiro.
  Future<List<NotaPagina>> listarPorPagina(String pagina) async {
    final recs = await _c.getFullList(
      filter: 'pagina = "$pagina"',
      sort: '-created',
    );
    return recs.map(NotaPagina.fromRecord).toList();
  }

  Future<void> criar({required String pagina, required String texto}) async {
    await _c.create(
      body: {'empresa': _empresaId, 'pagina': pagina, 'texto': texto.trim()},
    );
  }

  Future<void> marcarResolvida(String id, bool resolvida) =>
      _c.update(id, body: {'resolvida': resolvida});

  Future<void> apagar(String id) => _c.delete(id);
}
