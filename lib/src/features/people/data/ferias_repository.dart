import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../domain/ferias.dart';

final feriasRepositoryProvider = Provider<FeriasRepository>((ref) {
  return FeriasRepository(ref.watch(pbProvider), requireEmpresaId(ref));
});

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// A data (sem horas) de um campo `date` do PocketBase: só os 10 primeiros
/// caracteres, para não haver surpresas com fusos horários.
DateTime _dia(String s) {
  final p = s.length >= 10 ? s.substring(0, 10).split('-') : const <String>[];
  if (p.length != 3) return DateTime.now();
  return DateTime(
    int.tryParse(p[0]) ?? 2000,
    int.tryParse(p[1]) ?? 1,
    int.tryParse(p[2]) ?? 1,
  );
}

/// Férias e ausências (`ferias`) e o direito a férias de cada um (`ferias_direito`).
class FeriasRepository {
  FeriasRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String _empresaId;

  RecordService get _c => _pb.collection('ferias');
  RecordService get _d => _pb.collection('ferias_direito');

  String? get utilizadorId => _pb.authStore.record?.id;

  static Ausencia desdeRecord(RecordModel r) => Ausencia(
    id: r.id,
    pessoa: r.getStringValue('pessoa'),
    nome: r.getStringValue('nome'),
    tipo: TipoAusencia.fromApi(r.getStringValue('tipo')),
    de: _dia(r.getStringValue('data_inicio')),
    ate: _dia(r.getStringValue('data_fim')),
    estado: EstadoAusencia.fromApi(r.getStringValue('estado')),
    diasUteis: r.getIntValue('dias_uteis'),
    notas: r.getStringValue('notas'),
  );

  /// As ausências que tocam o [ano]. O servidor só devolve o que cada um pode ver.
  Future<List<Ausencia>> doAno(int ano) async {
    final recs = await _c.getFullList(
      filter:
          'empresa = "$_empresaId" && data_inicio <= "$ano-12-31 23:59:59.999Z" '
          '&& data_fim >= "$ano-01-01 00:00:00.000Z"',
      sort: 'data_inicio',
    );
    return recs.map(desdeRecord).toList();
  }

  Future<void> criar({
    required String pessoa,
    required String nome,
    String userId = '',
    required TipoAusencia tipo,
    required DateTime de,
    required DateTime ate,
    required EstadoAusencia estado,
    String notas = '',
  }) => _c.create(
    body: {
      'empresa': _empresaId,
      'pessoa': pessoa,
      'nome': nome.trim(),
      if (userId.isNotEmpty) 'user': userId,
      'tipo': tipo.api,
      'data_inicio': '${_ymd(de)} 00:00:00.000Z',
      'data_fim': '${_ymd(ate)} 00:00:00.000Z',
      'dias_uteis': diasUteisEntre(de, ate),
      'estado': estado.api,
      'notas': notas.trim(),
      if (estado != EstadoAusencia.pedido && utilizadorId != null)
        'decidido_por': utilizadorId,
      if (estado != EstadoAusencia.pedido)
        'decidido_em': '${_ymd(DateTime.now())} 00:00:00.000Z',
    },
  );

  Future<void> decidir(String id, EstadoAusencia estado) => _c.update(
    id,
    body: {
      'estado': estado.api,
      if (utilizadorId != null) 'decidido_por': utilizadorId,
      'decidido_em': '${_ymd(DateTime.now())} 00:00:00.000Z',
    },
  );

  Future<void> apagar(String id) => _c.delete(id);

  /// Direito a férias de cada pessoa no [ano] (chave da pessoa → dias).
  Future<Map<String, int>> direitos(int ano) async {
    final recs = await _d.getFullList(
      filter: 'empresa = "$_empresaId" && ano = $ano',
    );
    return {
      for (final r in recs) r.getStringValue('pessoa'): r.getIntValue('dias'),
    };
  }

  Future<void> definirDireito({
    required String pessoa,
    String userId = '',
    required int ano,
    required int dias,
  }) async {
    final existentes = await _d.getList(
      perPage: 1,
      filter: 'empresa = "$_empresaId" && pessoa = "$pessoa" && ano = $ano',
    );
    if (existentes.items.isNotEmpty) {
      await _d.update(existentes.items.first.id, body: {'dias': dias});
    } else {
      await _d.create(
        body: {
          'empresa': _empresaId,
          'pessoa': pessoa,
          if (userId.isNotEmpty) 'user': userId,
          'ano': ano,
          'dias': dias,
        },
      );
    }
  }
}
