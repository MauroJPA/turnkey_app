import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../domain/equipamento.dart';

final equipamentosRepositoryProvider = Provider<EquipamentosRepository>((ref) {
  return EquipamentosRepository(ref.watch(pbProvider), requireEmpresaId(ref));
});

class EquipamentosRepository {
  EquipamentosRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String _empresaId;

  RecordService get _c => _pb.collection('equipamentos');

  Future<List<Equipamento>> list({bool incluirArquivados = false}) async {
    final filtros = ['empresa = "$_empresaId"'];
    if (!incluirArquivados) filtros.add('arquivado = false');
    final recs = await _c.getFullList(
      filter: filtros.join(' && '),
      sort: 'nome',
    );
    return recs.map(Equipamento.fromRecord).toList();
  }

  /// Soma da depreciação mensal dos equipamentos ativos — usada no painel
  /// financeiro/DRE e nos números mágicos.
  Future<double> totalMensal() async {
    final equipamentos = await list();
    return equipamentos.fold<double>(0, (s, e) => s + e.custoMensal);
  }

  Future<Equipamento> create(EquipamentoInput input) async {
    final rec = await _c.create(
      body: {...input.toBody(), 'empresa': _empresaId, 'arquivado': false},
    );
    return Equipamento.fromRecord(rec);
  }

  Future<Equipamento> update(String id, EquipamentoInput input) async =>
      Equipamento.fromRecord(await _c.update(id, body: input.toBody()));

  Future<void> setArquivado(String id, {required bool arquivado}) =>
      _c.update(id, body: {'arquivado': arquivado});

  Future<void> hardDelete(String id) => _c.delete(id);
}
