import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/pocketbase/pb_client.dart';
import '../../pricing/domain/dias_trabalho.dart';
import '../domain/escala.dart';

final escalaRepositoryProvider = Provider<EscalaRepository>((ref) {
  return EscalaRepository(ref.watch(pbProvider), requireEmpresaId(ref));
});

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _dia(String s) {
  final p = s.length >= 10 ? s.substring(0, 10).split('-') : const <String>[];
  if (p.length != 3) return DateTime.now();
  return DateTime(
    int.tryParse(p[0]) ?? 2000,
    int.tryParse(p[1]) ?? 1,
    int.tryParse(p[2]) ?? 1,
  );
}

/// O horário de um dia da semana, para guardar.
typedef HorarioDia = ({int inicio, int fim, int pausaMin});

/// Escala da equipa: o horário habitual (`escala_modelo`) e as alterações
/// de dias concretos (`escala_excecoes`).
class EscalaRepository {
  EscalaRepository(this._pb, this._empresaId);

  final PocketBase _pb;
  final String _empresaId;

  RecordService get _m => _pb.collection('escala_modelo');
  RecordService get _e => _pb.collection('escala_excecoes');
  RecordService get _r => _pb.collection('escala_regras');

  String? get utilizadorId => _pb.authStore.record?.id;

  Future<List<TurnoModelo>> modelo() async {
    final recs = await _m.getFullList(filter: 'empresa = "$_empresaId"');
    return [
      for (final r in recs)
        if (lerHora(r.getStringValue('inicio')) case final i?)
          if (lerHora(r.getStringValue('fim')) case final f?)
            TurnoModelo(
              id: r.id,
              pessoa: r.getStringValue('pessoa'),
              nome: r.getStringValue('nome'),
              userId: r.getStringValue('user'),
              diaSemana: r.getIntValue('dia_semana'),
              inicio: i,
              fim: f,
              pausaMin: r.getIntValue('pausa_min'),
            ),
    ];
  }

  Future<List<ExcecaoEscala>> excecoes({
    required DateTime de,
    required DateTime ate,
  }) async {
    final recs = await _e.getFullList(
      filter:
          'empresa = "$_empresaId" && data >= "${_ymd(de)} 00:00:00.000Z" '
          '&& data < "${_ymd(ate)} 00:00:00.000Z"',
    );
    return [
      for (final r in recs)
        ExcecaoEscala(
          id: r.id,
          pessoa: r.getStringValue('pessoa'),
          nome: r.getStringValue('nome'),
          userId: r.getStringValue('user'),
          data: _dia(r.getStringValue('data')),
          folga: r.getBoolValue('folga'),
          inicio: lerHora(r.getStringValue('inicio')),
          fim: lerHora(r.getStringValue('fim')),
          pausaMin: r.getIntValue('pausa_min'),
          notas: r.getStringValue('notas'),
        ),
    ];
  }

  /// Todas as regras de horário (da mais antiga à mais recente: a última que
  /// cobre um dia é a que manda).
  Future<List<RegraEscala>> regras() async {
    final recs = await _r.getFullList(
      filter: 'empresa = "$_empresaId"',
      sort: 'created',
    );
    return [
      for (final r in recs)
        RegraEscala(
          id: r.id,
          lote: r.getStringValue('lote'),
          pessoa: r.getStringValue('pessoa'),
          nome: r.getStringValue('nome'),
          userId: r.getStringValue('user'),
          dias: lerDiasTrabalho(r.getStringValue('dias')),
          de: _dia(r.getStringValue('de')),
          ate: r.getStringValue('ate').length >= 10
              ? _dia(r.getStringValue('ate'))
              : null,
          folga: r.getBoolValue('folga'),
          inicio: lerHora(r.getStringValue('inicio')),
          fim: lerHora(r.getStringValue('fim')),
          pausaMin: r.getIntValue('pausa_min'),
          cadaSemanas: r.getIntValue('cada_semanas') < 1
              ? 1
              : r.getIntValue('cada_semanas'),
          saltarFeriados: r.getBoolValue('saltar_feriados'),
          notas: r.getStringValue('notas'),
        ),
    ];
  }

  /// Cria a mesma regra para várias pessoas de uma vez (um registo por pessoa,
  /// todos com o mesmo lote). Devolve o lote.
  Future<String> criarLote({
    required List<({String pessoa, String nome, String userId})> pessoas,
    required Set<int> dias,
    required DateTime de,
    DateTime? ate,
    HorarioDia? horario,
    int cadaSemanas = 1,
    bool saltarFeriados = false,
    String notas = '',
  }) async {
    final lote = _novoLote();
    for (final p in pessoas) {
      await _r.create(
        body: {
          'empresa': _empresaId,
          'lote': lote,
          'pessoa': p.pessoa,
          'nome': p.nome.trim(),
          if (p.userId.isNotEmpty) 'user': p.userId,
          'dias': escreverDiasLista(dias),
          'folga': horario == null,
          'inicio': horario == null ? '' : escreverHora(horario.inicio),
          'fim': horario == null ? '' : escreverHora(horario.fim),
          'pausa_min': horario?.pausaMin ?? 0,
          'de': '${_ymd(de)} 00:00:00.000Z',
          'ate': ate == null ? '' : '${_ymd(ate)} 00:00:00.000Z',
          'cada_semanas': cadaSemanas,
          'saltar_feriados': saltarFeriados,
          'notas': notas.trim(),
        },
      );
    }
    return lote;
  }

  /// Apaga a regra de todas as pessoas do lote (ou só a de [pessoa]).
  Future<void> apagarLote(String lote, {String? pessoa}) async {
    final recs = await _r.getFullList(
      filter:
          'empresa = "$_empresaId" && lote = "$lote"'
          '${pessoa == null ? '' : ' && pessoa = "$pessoa"'}',
    );
    for (final r in recs) {
      await _r.delete(r.id);
    }
  }

  /// Faz a regra acabar em [ate] (inclusive) — "terminar aqui".
  Future<void> terminarLote(String lote, DateTime ate) async {
    final recs = await _r.getFullList(
      filter: 'empresa = "$_empresaId" && lote = "$lote"',
    );
    for (final r in recs) {
      await _r.update(r.id, body: {'ate': '${_ymd(ate)} 00:00:00.000Z'});
    }
  }

  static String _novoLote() {
    const letras = 'abcdefghijkmnpqrstuvwxyz23456789';
    final r = Random.secure();
    return List.generate(12, (_) => letras[r.nextInt(letras.length)]).join();
  }

  /// Substitui o horário habitual de uma pessoa: os dias de [dias] ficam com
  /// esse horário e os outros passam a folga.
  Future<void> guardarModelo({
    required String pessoa,
    required String nome,
    String userId = '',
    required Map<int, HorarioDia> dias,
  }) async {
    final existentes = await _m.getFullList(
      filter: 'empresa = "$_empresaId" && pessoa = "$pessoa"',
    );
    final porDia = {for (final r in existentes) r.getIntValue('dia_semana'): r};
    for (final e in porDia.entries) {
      if (!dias.containsKey(e.key)) await _m.delete(e.value.id);
    }
    for (final e in dias.entries) {
      final corpo = {
        'nome': nome.trim(),
        'inicio': escreverHora(e.value.inicio),
        'fim': escreverHora(e.value.fim),
        'pausa_min': e.value.pausaMin,
      };
      final atual = porDia[e.key];
      if (atual != null) {
        await _m.update(atual.id, body: corpo);
      } else {
        await _m.create(
          body: {
            ...corpo,
            'empresa': _empresaId,
            'pessoa': pessoa,
            if (userId.isNotEmpty) 'user': userId,
            'dia_semana': e.key,
          },
        );
      }
    }
  }

  /// Muda um dia concreto: um turno (se [horario] existe) ou uma folga.
  Future<void> definirExcecao({
    required String pessoa,
    required String nome,
    String userId = '',
    required DateTime dia,
    HorarioDia? horario,
    String notas = '',
  }) async {
    final existente = await _e.getList(
      perPage: 1,
      filter:
          'empresa = "$_empresaId" && pessoa = "$pessoa" && data = "${_ymd(dia)} 00:00:00.000Z"',
    );
    final corpo = {
      'nome': nome.trim(),
      'folga': horario == null,
      'inicio': horario == null ? '' : escreverHora(horario.inicio),
      'fim': horario == null ? '' : escreverHora(horario.fim),
      'pausa_min': horario?.pausaMin ?? 0,
      'notas': notas.trim(),
    };
    if (existente.items.isNotEmpty) {
      await _e.update(existente.items.first.id, body: corpo);
    } else {
      await _e.create(
        body: {
          ...corpo,
          'empresa': _empresaId,
          'pessoa': pessoa,
          if (userId.isNotEmpty) 'user': userId,
          'data': '${_ymd(dia)} 00:00:00.000Z',
        },
      );
    }
  }

  /// Volta ao horário habitual nesse dia.
  Future<void> removerExcecao({
    required String pessoa,
    required DateTime dia,
  }) async {
    final existente = await _e.getList(
      perPage: 1,
      filter:
          'empresa = "$_empresaId" && pessoa = "$pessoa" && data = "${_ymd(dia)} 00:00:00.000Z"',
    );
    for (final r in existente.items) {
      await _e.delete(r.id);
    }
  }
}
