import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../../schedule/domain/production_plan.dart';
import '../domain/mep_plano.dart';

final mepRepositoryProvider = Provider<MepRepository>((ref) {
  return MepRepository(ref.watch(pbProvider), requireEmpresaId(ref));
});

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

class MepRepository {
  MepRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String _empresaId;

  Future<MepPlano> plano(
    String receitaId,
    double kg, {
    String? formatoId,
    String? recheioId,
  }) async {
    final res = await _pb.send(
      '/api/turnkey/receitas/$receitaId/plano',
      method: 'GET',
      query: {
        'kg': '$kg',
        if (formatoId != null && formatoId.isNotEmpty) 'formato': formatoId,
        if (recheioId != null && recheioId.isNotEmpty) 'recheio': recheioId,
      },
    );
    return MepPlano.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// Mise en place de um produto final (ficha técnica) para [unidades].
  Future<MepPlano> planoFicha(String fichaId, int unidades) async {
    final res = await _pb.send(
      '/api/turnkey/fichas/$fichaId/plano',
      method: 'GET',
      query: {'unidades': '$unidades'},
    );
    return MepPlano.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// Regista a produção (concluída) na agenda, dá baixa no stock e — se
  /// [gerarCompras] — envia o que faltou para a lista de compras.
  Future<({String planoId, ConclusaoResumo resumo, int linhasCompra})>
      produzirAgora(
    String receitaId,
    double kg, {
    String? formatoId,
    String? recheioId,
    String? fichaId,
    required String tituloReceita,
    bool gerarCompras = false,
  }) async {
    final plano = await _pb.collection('producoes').create(body: {
      'empresa': _empresaId,
      'data': _ymd(DateTime.now()),
      'titulo': 'Mise en place - $tituloReceita',
      'estado': 'planeada',
    });
    await _pb.collection('producao_itens').create(body: {
      'empresa': _empresaId,
      'producao': plano.id,
      'receita': receitaId,
      'quantidade_kg': kg,
      if (formatoId != null && formatoId.isNotEmpty) 'formato': formatoId,
      if (recheioId != null && recheioId.isNotEmpty) 'recheio': recheioId,
      if (fichaId != null && fichaId.isNotEmpty) 'ficha': fichaId,
      'prioridade': 'media',
    });

    var linhas = 0;
    if (gerarCompras) {
      final lc = await _pb.send(
        '/api/turnkey/producoes/${plano.id}/lista-compras',
        method: 'POST',
      );
      linhas = ((lc as Map)['linhas'] as num?)?.toInt() ?? 0;
    }

    final res = await _pb.send(
      '/api/turnkey/producoes/${plano.id}/concluir',
      method: 'POST',
    );
    return (
      planoId: plano.id,
      resumo: ConclusaoResumo.fromJson(Map<String, dynamic>.from(res as Map)),
      linhasCompra: linhas,
    );
  }
}
