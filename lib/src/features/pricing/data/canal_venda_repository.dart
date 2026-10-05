import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../domain/canal_venda.dart';

final canalVendaRepositoryProvider = Provider<CanalVendaRepository>((ref) {
  return CanalVendaRepository(ref.watch(pbProvider), requireEmpresaId(ref));
});

/// Os canais de venda (plataformas, revendedores…) com as suas taxas.
class CanalVendaRepository {
  CanalVendaRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String _empresaId;

  RecordService get _c => _pb.collection('canais_venda');

  Map<String, dynamic> _body({
    required String nome,
    required List<TaxaCanal> taxas,
    required bool embalagemPlataforma,
    int ordem = 0,
  }) => {
    'nome': nome.trim(),
    'taxas': [for (final t in taxas) t.toJson()],
    'embalagem_plataforma': embalagemPlataforma,
    'ordem': ordem,
  };

  Future<List<CanalVenda>> list() async {
    final recs = await _c.getFullList(
      filter: 'empresa = "$_empresaId"',
      sort: 'ordem,nome',
    );
    return recs.map(CanalVenda.fromRecord).toList();
  }

  Future<CanalVenda> create({
    required String nome,
    required List<TaxaCanal> taxas,
    required bool embalagemPlataforma,
    int ordem = 0,
  }) async => CanalVenda.fromRecord(
    await _c.create(
      body: {
        ..._body(
          nome: nome,
          taxas: taxas,
          embalagemPlataforma: embalagemPlataforma,
          ordem: ordem,
        ),
        'empresa': _empresaId,
      },
    ),
  );

  Future<CanalVenda> update(
    String id, {
    required String nome,
    required List<TaxaCanal> taxas,
    required bool embalagemPlataforma,
    int ordem = 0,
  }) async => CanalVenda.fromRecord(
    await _c.update(
      id,
      body: _body(
        nome: nome,
        taxas: taxas,
        embalagemPlataforma: embalagemPlataforma,
        ordem: ordem,
      ),
    ),
  );

  Future<void> delete(String id) => _c.delete(id);
}

/// Os canais de venda da empresa ativa.
final canaisVendaProvider = FutureProvider.autoDispose<List<CanalVenda>>((ref) {
  return ref.watch(canalVendaRepositoryProvider).list();
});
