import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../domain/production_plan.dart';

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepository(ref.watch(pbProvider), requireEmpresaId(ref));
});

String _ymd(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

class ScheduleRepository {
  ScheduleRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String _empresaId;

  RecordService get _planos => _pb.collection('producoes');
  RecordService get _itens => _pb.collection('producao_itens');

  Future<List<ProducaoPlan>> listPlans() async {
    final recs = await _planos.getFullList(
      filter: 'empresa = "$_empresaId"',
      sort: '-data,-created',
    );
    return recs.map(ProducaoPlan.fromRecord).toList();
  }

  Future<ProducaoPlan> getPlan(String id) async =>
      ProducaoPlan.fromRecord(await _planos.getOne(id));

  Future<ProducaoPlan> createPlan({
    required DateTime data,
    String titulo = '',
    List<String> nomesReceitas = const [],
  }) async {
    final t = titulo.trim().isEmpty
        ? tituloPadraoProducao(data, nomesReceitas)
        : titulo.trim();
    final rec = await _planos.create(
      body: {
        'empresa': _empresaId,
        'data': _ymd(data),
        'titulo': t,
        'estado': EstadoProducao.planeada.api,
      },
    );
    return ProducaoPlan.fromRecord(rec);
  }

  Future<ProducaoPlan> updatePlan(
    String id, {
    DateTime? data,
    String? titulo,
    String? notas,
  }) async {
    final rec = await _planos.update(id, body: {
      if (data != null) 'data': _ymd(data),
      if (titulo != null) 'titulo': titulo,
      if (notas != null) 'notas': notas,
    });
    return ProducaoPlan.fromRecord(rec);
  }

  Future<void> deletePlan(String id) => _planos.delete(id);

  Future<List<ProducaoItem>> listItens(String planId) async {
    final recs = await _itens.getFullList(
      filter: 'producao = "$planId"',
      sort: 'created',
      expand: 'receita,formato,recheio,ficha',
    );
    return recs.map(ProducaoItem.fromRecord).toList();
  }

  /// Todas as linhas de produção da empresa (qualquer plano), com o id do
  /// plano a que pertencem — para o Relatório geral.
  Future<List<({String producaoId, ProducaoItem item})>>
  listTodosItens() async {
    final recs = await _itens.getFullList(
      filter: 'empresa = "$_empresaId"',
      expand: 'receita,formato,recheio,ficha',
    );
    return [
      for (final r in recs)
        (producaoId: r.getStringValue('producao'), item: ProducaoItem.fromRecord(r)),
    ];
  }

  Future<void> addItem(
    String planId, {
    required String receitaId,
    required double quantidadeKg,
    String? formatoId,
    String? recheioId,
    String? fichaId,
    String prioridade = 'media',
    String horaLimite = '',
    int unidadesPrevistas = 0,
  }) async {
    await _itens.create(body: {
      'empresa': _empresaId,
      'producao': planId,
      'receita': receitaId,
      'quantidade_kg': quantidadeKg,
      if (formatoId != null) 'formato': formatoId,
      if (recheioId != null) 'recheio': recheioId,
      if (fichaId != null && fichaId.isNotEmpty) 'ficha': fichaId,
      'prioridade': prioridade,
      if (horaLimite.isNotEmpty) 'hora_limite': horaLimite,
      'unidades_previstas': unidadesPrevistas,
    });
  }

  Future<void> updateItem(String itemId, {required double quantidadeKg}) async {
    await _itens.update(itemId, body: {'quantidade_kg': quantidadeKg});
  }

  Future<void> removeItem(String itemId) => _itens.delete(itemId);

  /// Id do formato mais usado nas produções anteriores desta receita
  /// (para pré-selecionar). `''` se ainda não há histórico.
  Future<String> formatoMaisUsado(String receitaId) async {
    final recs = await _itens.getFullList(
      filter: 'receita = "$receitaId" && formato != ""',
      fields: 'formato',
      sort: '-created',
    );
    if (recs.isEmpty) return '';
    final contagem = <String, int>{};
    for (final r in recs) {
      final f = r.getStringValue('formato');
      if (f.isNotEmpty) contagem[f] = (contagem[f] ?? 0) + 1;
    }
    if (contagem.isEmpty) return '';
    return contagem.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  /// Ficha técnica que corresponde a uma massa + formato (+ recheio), com os
  /// componentes (recheios/coberturas/extra). `fichaId` vazio se não houver.
  Future<FichaResolvida> resolverFicha({
    required String massaId,
    required String formatoId,
    String? recheioId,
  }) async {
    final res = await _pb.send(
      '/api/gc_turnkey/fichas/resolver',
      method: 'GET',
      query: {
        'massa': massaId,
        'formato': formatoId,
        if (recheioId != null && recheioId.isNotEmpty) 'recheio': recheioId,
      },
    );
    return FichaResolvida.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// Nº de linhas já na lista de compras para esta produção.
  Future<int> contarLinhasCompra(String planId) async {
    final res = await _pb.collection('lista_compras').getList(
          page: 1,
          perPage: 1,
          filter: 'producao = "$planId"',
        );
    return res.totalItems;
  }

  Future<PlanoResposta> plano(String planId) async {
    final res = await _pb.send(
      '/api/gc_turnkey/producoes/$planId/plano',
      method: 'GET',
    );
    return PlanoResposta.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// Gera/atualiza as linhas da lista de compras a partir deste plano.
  /// Devolve o nº de linhas escritas.
  Future<int> gerarListaCompras(String planId) async {
    final res = await _pb.send(
      '/api/gc_turnkey/producoes/$planId/lista-compras',
      method: 'POST',
    );
    return ((res as Map)['linhas'] as num?)?.toInt() ?? 0;
  }

  Future<ConclusaoResumo> concluir(String planId) async {
    final res = await _pb.send(
      '/api/gc_turnkey/producoes/$planId/concluir',
      method: 'POST',
    );
    return ConclusaoResumo.fromJson(Map<String, dynamic>.from(res as Map));
  }
}
