import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../domain/lote.dart';

class LotesRepository {
  LotesRepository(this._pb, this._empresaId);
  final PocketBase _pb;
  final String _empresaId;

  String _q(String s) => s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');

  Future<List<LoteProducao>> recentes({int max = 100}) async {
    final r = await _pb
        .collection('lotes_producao')
        .getList(
          perPage: max,
          filter: 'empresa = "$_empresaId"',
          sort: '-data_producao,-created',
        );
    return r.items.map(LoteProducao.fromRecord).toList();
  }

  Future<LoteProducao?> porCodigo(String codigo) async {
    final r = await _pb
        .collection('lotes_producao')
        .getList(
          perPage: 1,
          filter: 'empresa = "$_empresaId" && codigo = "${_q(codigo)}"',
        );
    return r.items.isEmpty ? null : LoteProducao.fromRecord(r.items.first);
  }

  /// Os lotes de produção em que entrou o lote [lote] de um ingrediente
  /// (para saber o que retirar se houver um problema com esse lote).
  Future<List<LoteProducao>> ondeFoiUsado(String lote) async {
    final r = await _pb
        .collection('lotes_producao')
        .getList(
          perPage: 100,
          filter: 'empresa = "$_empresaId" && ingredientes ~ "${_q(lote)}"',
          sort: '-data_producao',
        );
    return [
      for (final l in r.items.map(LoteProducao.fromRecord))
        if (l.ingredientes.any((i) => i.lote == lote)) l,
    ];
  }

  /// O próximo número de lote deste produto neste dia.
  Future<int> proximaSequencia(DateTime data, String produto) async {
    final base = codigoLote(data, produto, 0);
    final prefixo = base.substring(0, base.length - 1); // "261006-ALB-"
    final r = await _pb
        .collection('lotes_producao')
        .getList(
          perPage: 100,
          filter: 'empresa = "$_empresaId" && codigo ~ "${_q(prefixo)}"',
        );
    var max = 0;
    for (final x in r.items) {
      final c = x.getStringValue('codigo');
      if (!c.startsWith(prefixo)) continue;
      final n = int.tryParse(c.substring(prefixo.length)) ?? 0;
      if (n > max) max = n;
    }
    return max + 1;
  }

  Future<List<IngredienteComLotes>> ingredientesDaFicha(String fichaId) async {
    final res = await _pb.send(
      '/api/gc_turnkey/lotes/ingredientes',
      query: {'ficha': fichaId},
    );
    final m = res is Map ? res : const <String, dynamic>{};
    return [
      for (final i in (m['ingredientes'] as List? ?? const []))
        if (i is Map)
          IngredienteComLotes.fromJson(Map<String, dynamic>.from(i)),
    ];
  }

  /// Regista o lote de um ingrediente (se já existir, devolve o existente).
  Future<LoteSugerido> registarLoteIngrediente({
    required String ingredienteId,
    required String lote,
    DateTime? validade,
    String fornecedor = '',
  }) async {
    try {
      final rec = await _pb
          .collection('lotes_ingrediente')
          .create(
            body: {
              'empresa': _empresaId,
              'ingrediente': ingredienteId,
              'lote': lote.trim(),
              'validade': validade == null ? '' : dataParaPb(validade),
              'data_entrada': dataParaPb(DateTime.now()),
              'fornecedor': fornecedor.trim(),
            },
          );
      return LoteSugerido(
        id: rec.id,
        lote: lote.trim(),
        validade: validade,
        fornecedor: fornecedor.trim(),
      );
    } on ClientException {
      final ex = await _pb
          .collection('lotes_ingrediente')
          .getList(
            perPage: 1,
            filter:
                'empresa = "$_empresaId" && ingrediente = "$ingredienteId" && lote = "${_q(lote.trim())}"',
          );
      if (ex.items.isEmpty) rethrow;
      final l = LoteIngrediente.fromRecord(ex.items.first);
      return LoteSugerido(
        id: l.id,
        lote: l.lote,
        validade: l.validade,
        fornecedor: l.fornecedor,
      );
    }
  }

  Future<LoteProducao> criar({
    required String fichaId,
    required String fichaNome,
    required DateTime data,
    required double quantidade,
    DateTime? validade,
    required List<LoteUsado> ingredientes,
    String responsavel = '',
    String notas = '',
  }) async {
    // o código é único: se alguém criou outro entretanto, passa ao seguinte
    var seq = await proximaSequencia(data, fichaNome);
    for (var tentativa = 0; tentativa < 5; tentativa++) {
      try {
        final rec = await _pb
            .collection('lotes_producao')
            .create(
              body: {
                'empresa': _empresaId,
                'codigo': codigoLote(data, fichaNome, seq),
                'ficha': fichaId,
                'ficha_nome': fichaNome,
                'data_producao': dataParaPb(data),
                'quantidade': quantidade,
                'validade': validade == null ? '' : dataParaPb(validade),
                'ingredientes': [for (final i in ingredientes) i.toJson()],
                'responsavel': responsavel,
                'notas': notas,
              },
            );
        return LoteProducao.fromRecord(rec);
      } on ClientException catch (e) {
        final dup = e.response.toString().contains('validation_not_unique');
        if (!dup) rethrow;
        seq++;
      }
    }
    throw StateError('Não consegui gerar um código de lote único.');
  }

  Future<void> apagar(String id) => _pb.collection('lotes_producao').delete(id);
}

final lotesRepositoryProvider = Provider<LotesRepository>(
  (ref) => LotesRepository(ref.watch(pbProvider), requireEmpresaId(ref)),
);

final lotesRecentesProvider = FutureProvider.autoDispose<List<LoteProducao>>(
  (ref) => ref.watch(lotesRepositoryProvider).recentes(),
);

final loteProvider = FutureProvider.autoDispose.family<LoteProducao?, String>(
  (ref, codigo) => ref.watch(lotesRepositoryProvider).porCodigo(codigo),
);
