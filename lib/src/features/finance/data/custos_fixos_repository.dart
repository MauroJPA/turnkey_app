import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../domain/custo_fixo.dart';

final custosFixosRepositoryProvider = Provider<CustosFixosRepository>((ref) {
  return CustosFixosRepository(ref.watch(pbProvider), requireEmpresaId(ref));
});

class CustosFixosRepository {
  CustosFixosRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String _empresaId;

  RecordService get _c => _pb.collection('custos_fixos');

  Future<List<CustoFixo>> list({bool incluirArquivados = false}) async {
    final filtros = ['empresa = "$_empresaId"'];
    if (!incluirArquivados) filtros.add('arquivado = false');
    final recs = await _c.getFullList(
      filter: filtros.join(' && '),
      sort: 'nome',
    );
    return recs.map(CustoFixo.fromRecord).toList();
  }

  /// Soma dos custos fixos/variáveis ativos — usada pelo painel financeiro.
  Future<double> totalMensal({TipoCusto? tipo}) async {
    final custos = await list();
    return custos
        .where((c) => tipo == null || c.tipo == tipo)
        .fold<double>(0, (s, c) => s + c.valorMensal);
  }

  Future<CustoFixo> create(CustoFixoInput input) async {
    final rec = await _c.create(
      body: {...input.toBody(), 'empresa': _empresaId, 'arquivado': false},
    );
    return CustoFixo.fromRecord(rec);
  }

  Future<CustoFixo> update(String id, CustoFixoInput input) async =>
      CustoFixo.fromRecord(await _c.update(id, body: input.toBody()));

  Future<void> setArquivado(String id, {required bool arquivado}) =>
      _c.update(id, body: {'arquivado': arquivado});

  Future<void> hardDelete(String id) => _c.delete(id);
}
