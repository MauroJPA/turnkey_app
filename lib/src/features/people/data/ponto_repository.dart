import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/formatting/pb_data_hora.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../domain/ponto.dart';

final pontoRepositoryProvider = Provider<PontoRepository>((ref) {
  return PontoRepository(ref.watch(pbProvider), requireEmpresaId(ref));
});

/// Marcações de ponto (`ponto_registos`).
class PontoRepository {
  PontoRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String _empresaId;

  RecordService get _c => _pb.collection('ponto_registos');

  /// O id do utilizador autenticado.
  String? get utilizadorId => _pb.authStore.record?.id;

  static RegistoPonto desdeRecord(RecordModel r) {
    DateTime? d(String f) {
      final s = r.getStringValue(f);
      return s.isEmpty ? null : DateTime.tryParse(s)?.toLocal();
    }

    return RegistoPonto(
      id: r.id,
      pessoa: r.getStringValue('pessoa'),
      nome: r.getStringValue('nome'),
      tipo: TipoPonto.fromApi(r.getStringValue('tipo')) ?? TipoPonto.entrada,
      dataHora: d('data_hora') ?? DateTime.now(),
      origem: OrigemPonto.fromApi(r.getStringValue('origem')),
      notas: r.getStringValue('notas'),
      corrigido: r.getBoolValue('corrigido'),
      dataHoraOriginal: d('data_hora_original'),
    );
  }

  /// As marcações entre [desde] (inclusive) e [ate] (exclusive). O servidor
  /// devolve todas ao administrador e só as próprias aos outros.
  Future<List<RegistoPonto>> listar({
    required DateTime desde,
    required DateTime ate,
  }) async {
    final recs = await _c.getFullList(
      filter:
          'empresa = "$_empresaId" && data_hora >= "${pbDataHora(desde)}" '
          '&& data_hora < "${pbDataHora(ate)}"',
      sort: 'data_hora',
    );
    return recs.map(desdeRecord).toList();
  }

  Future<void> registar({
    String? id,
    required String pessoa,
    required String nome,
    String userId = '',
    required TipoPonto tipo,
    required DateTime dataHora,
    OrigemPonto origem = OrigemPonto.app,
    String notas = '',
  }) => _c.create(
    body: {
      if (id != null) 'id': id,
      'empresa': _empresaId,
      'pessoa': pessoa,
      'nome': nome.trim(),
      if (userId.isNotEmpty) 'user': userId,
      'tipo': tipo.api,
      'data_hora': pbDataHora(dataHora),
      'origem': origem.api,
      'notas': notas.trim(),
      if (utilizadorId != null) 'autor': utilizadorId,
    },
  );

  /// Corrige a hora (e o tipo) de uma marcação, guardando a hora original.
  Future<void> corrigir(
    RegistoPonto r, {
    required DateTime dataHora,
    required TipoPonto tipo,
    String notas = '',
  }) => _c.update(
    r.id,
    body: {
      'data_hora': pbDataHora(dataHora),
      'tipo': tipo.api,
      'notas': notas.trim(),
      'corrigido': true,
      'data_hora_original': pbDataHora(r.dataHoraOriginal ?? r.dataHora),
    },
  );

  Future<void> apagar(String id) => _c.delete(id);

  /// A última marcação de cada pessoa nas últimas 36 horas (chave da pessoa).
  Future<Map<String, UltimoPonto>> estado() async {
    final res = await _pb.send('/api/gc_turnkey/ponto/estado');
    final m = res is Map ? res : const <String, dynamic>{};
    final out = <String, UltimoPonto>{};
    for (final p in (m['pessoas'] as List? ?? const [])) {
      if (p is! Map) continue;
      final t = TipoPonto.fromApi('${p['tipo']}');
      final d = DateTime.tryParse('${p['dataHora']}')?.toLocal();
      if (t != null && d != null) out['${p['pessoa']}'] = UltimoPonto(t, d);
    }
    return out;
  }
}
