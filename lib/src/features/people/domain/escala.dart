import '../../../core/printing/html_escape.dart';
import '../../pricing/domain/dias_trabalho.dart';
import 'ferias.dart';

/// "08:30" → 510 minutos desde a meia-noite; `null` se não for uma hora válida.
int? lerHora(String? s) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch((s ?? '').trim());
  if (m == null) return null;
  final h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  if (h > 23 || min > 59) return null;
  return h * 60 + min;
}

/// 510 → "08:30".
String escreverHora(int minutos) {
  final m = ((minutos % 1440) + 1440) % 1440;
  return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
}

/// Minutos de trabalho de um turno: do [inicio] ao [fim] (se o fim é igual ou
/// anterior ao início, passa da meia-noite) menos a [pausaMin].
int minutosDoTurno(int inicio, int fim, int pausaMin) {
  var dur = fim - inicio;
  if (dur <= 0) dur += 1440;
  dur -= pausaMin;
  return dur < 0 ? 0 : dur;
}

/// O horário habitual de uma pessoa num dia da semana (1 = segunda … 7 = domingo).
class TurnoModelo {
  const TurnoModelo({
    required this.pessoa,
    required this.diaSemana,
    required this.inicio,
    required this.fim,
    this.pausaMin = 0,
    this.nome = '',
    this.userId = '',
    this.id = '',
  });

  final String id;
  final String pessoa;
  final String nome;
  final String userId;
  final int diaSemana;
  final int inicio;
  final int fim;
  final int pausaMin;

  int get minutos => minutosDoTurno(inicio, fim, pausaMin);
}

/// O que muda num dia concreto: um turno diferente ou uma folga.
class ExcecaoEscala {
  const ExcecaoEscala({
    required this.pessoa,
    required this.data,
    this.folga = false,
    this.inicio,
    this.fim,
    this.pausaMin = 0,
    this.notas = '',
    this.nome = '',
    this.userId = '',
    this.id = '',
  });

  final String id;
  final String pessoa;
  final String nome;
  final String userId;
  final DateTime data;
  final bool folga;
  final int? inicio;
  final int? fim;
  final int pausaMin;
  final String notas;
}

/// Uma mudança ao horário habitual que se repete (criada em lote para várias
/// pessoas): nos [dias] da semana, a partir de [de], até [ate] (vazio = para
/// sempre), todas as semanas ou de [cadaSemanas] em [cadaSemanas].
class RegraEscala {
  const RegraEscala({
    required this.pessoa,
    required this.dias,
    required this.de,
    this.ate,
    this.folga = false,
    this.inicio,
    this.fim,
    this.pausaMin = 0,
    this.cadaSemanas = 1,
    this.saltarFeriados = false,
    this.notas = '',
    this.nome = '',
    this.userId = '',
    this.lote = '',
    this.id = '',
  });

  final String id;
  final String lote;
  final String pessoa;
  final String nome;
  final String userId;
  final Set<int> dias;
  final DateTime de;
  final DateTime? ate;
  final bool folga;
  final int? inicio;
  final int? fim;
  final int pausaMin;
  final int cadaSemanas;
  final bool saltarFeriados;
  final String notas;

  bool get eFolga => folga || inicio == null || fim == null;

  /// Esta regra manda no dia [dia]? (Ignora se a empresa fecha nesse dia: isso
  /// decide-se antes, em [diaDaEscala].)
  bool cobre(DateTime dia) {
    final d = _d(dia);
    if (d.isBefore(_d(de))) return false;
    if (ate != null && d.isAfter(_d(ate!))) return false;
    if (!dias.contains(d.weekday)) return false;
    if (cadaSemanas > 1) {
      final semanas =
          (segundaDaSemana(d).difference(segundaDaSemana(de)).inHours / 24)
              .round() ~/
          7;
      if (semanas % cadaSemanas != 0) return false;
    }
    if (saltarFeriados && feriadosNacionais(d.year).contains(d)) return false;
    return true;
  }

  /// "seg a sex · 08:00–16:30 · de 14/10 para sempre".
  String get resumo {
    final partes = <String>[
      resumoDiasTrabalho(dias),
      eFolga ? 'folga' : '${escreverHora(inicio!)}–${escreverHora(fim!)}',
      if (cadaSemanas == 2)
        'semanas alternadas'
      else if (cadaSemanas > 2)
        'de $cadaSemanas em $cadaSemanas semanas',
      ate == null
          ? 'desde ${_dmy(de)}, para sempre'
          : (_d(ate!) == _d(de)
                ? 'em ${_dmy(de)}'
                : 'de ${_dmy(de)} a ${_dmy(ate!)}'),
    ];
    return partes.join(' · ');
  }
}

String _dmy(DateTime d) => '${d.day}/${d.month}/${d.year}';

enum EstadoDia { turno, folga, ausente, fechado }

/// O que uma pessoa tem num dia.
class DiaEscala {
  const DiaEscala({
    required this.dia,
    required this.estado,
    this.inicio = 0,
    this.fim = 0,
    this.pausaMin = 0,
    this.excecao = false,
    this.regra = false,
    this.ausencia,
    this.notas = '',
  });

  final DateTime dia;
  final EstadoDia estado;
  final int inicio;
  final int fim;
  final int pausaMin;

  /// Vem de uma alteração para este dia (e não do horário habitual).
  final bool excecao;

  /// Vem de uma regra de horário (em lote), e não do horário habitual.
  final bool regra;
  final Ausencia? ausencia;
  final String notas;

  Duration get previsto => estado == EstadoDia.turno
      ? Duration(minutes: minutosDoTurno(inicio, fim, pausaMin))
      : Duration.zero;

  /// "08:00–16:30", "Folga", "Férias"…
  String get texto => switch (estado) {
    EstadoDia.turno => '${escreverHora(inicio)}–${escreverHora(fim)}',
    EstadoDia.folga => 'Folga',
    EstadoDia.fechado => 'Fechado',
    EstadoDia.ausente => ausencia?.tipo.label ?? 'Ausente',
  };
}

DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);

/// O dia de [pessoa] na escala: ausência aprovada (férias, baixa, falta) →
/// alteração para esse dia → empresa fechada (folga automática) → regra de
/// horário mais recente → horário habitual → folga.
DiaEscala diaDaEscala({
  required String pessoa,
  required DateTime dia,
  required Iterable<TurnoModelo> modelo,
  required Iterable<ExcecaoEscala> excecoes,
  Iterable<RegraEscala> regras = const [],
  Iterable<Ausencia> ausencias = const [],
  Set<int> diasTrabalho = todosOsDias,
}) {
  final d = _d(dia);
  for (final a in ausencias) {
    if (a.pessoa == pessoa &&
        a.estado == EstadoAusencia.aprovado &&
        a.cobre(d)) {
      return DiaEscala(dia: d, estado: EstadoDia.ausente, ausencia: a);
    }
  }
  for (final e in excecoes) {
    if (e.pessoa == pessoa && _d(e.data) == d) {
      if (e.folga || e.inicio == null || e.fim == null) {
        return DiaEscala(
          dia: d,
          estado: EstadoDia.folga,
          excecao: true,
          notas: e.notas,
        );
      }
      return DiaEscala(
        dia: d,
        estado: EstadoDia.turno,
        inicio: e.inicio!,
        fim: e.fim!,
        pausaMin: e.pausaMin,
        excecao: true,
        notas: e.notas,
      );
    }
  }
  if (!diasTrabalho.contains(d.weekday)) {
    return DiaEscala(dia: d, estado: EstadoDia.fechado);
  }
  // a regra mais recente (a última da lista) que cobre o dia manda
  RegraEscala? regra;
  for (final r in regras) {
    if (r.pessoa == pessoa && r.cobre(d)) regra = r;
  }
  if (regra != null) {
    if (regra.eFolga) {
      return DiaEscala(
        dia: d,
        estado: EstadoDia.folga,
        regra: true,
        notas: regra.notas,
      );
    }
    return DiaEscala(
      dia: d,
      estado: EstadoDia.turno,
      inicio: regra.inicio!,
      fim: regra.fim!,
      pausaMin: regra.pausaMin,
      regra: true,
      notas: regra.notas,
    );
  }
  for (final m in modelo) {
    if (m.pessoa == pessoa && m.diaSemana == d.weekday) {
      return DiaEscala(
        dia: d,
        estado: EstadoDia.turno,
        inicio: m.inicio,
        fim: m.fim,
        pausaMin: m.pausaMin,
      );
    }
  }
  return DiaEscala(dia: d, estado: EstadoDia.folga);
}

/// As horas previstas de [pessoa] de [de] (inclusive) a [ate] (exclusive).
Duration horasPrevistas({
  required String pessoa,
  required DateTime de,
  required DateTime ate,
  required Iterable<TurnoModelo> modelo,
  required Iterable<ExcecaoEscala> excecoes,
  Iterable<RegraEscala> regras = const [],
  Iterable<Ausencia> ausencias = const [],
  Set<int> diasTrabalho = todosOsDias,
}) {
  var total = Duration.zero;
  for (
    var d = _d(de);
    d.isBefore(_d(ate));
    d = DateTime(d.year, d.month, d.day + 1)
  ) {
    total += diaDaEscala(
      pessoa: pessoa,
      dia: d,
      modelo: modelo,
      excecoes: excecoes,
      regras: regras,
      ausencias: ausencias,
      diasTrabalho: diasTrabalho,
    ).previsto;
  }
  return total;
}

/// Quando acaba o turno de [d] (no dia seguinte se passa da meia-noite);
/// `null` se não há turno.
DateTime? fimDoTurno(DiaEscala d) {
  if (d.estado != EstadoDia.turno) return null;
  var fim = DateTime(
    d.dia.year,
    d.dia.month,
    d.dia.day,
    d.fim ~/ 60,
    d.fim % 60,
  );
  if (d.fim <= d.inicio) fim = fim.add(const Duration(days: 1));
  return fim;
}

/// A segunda-feira da semana de [d].
DateTime segundaDaSemana(DateTime d) {
  final x = _d(d);
  return DateTime(x.year, x.month, x.day - (x.weekday - 1));
}

/// "+1h 20m" / "−35m" / "0m": a diferença entre o trabalhado e o previsto.
String saldoTexto(Duration d) {
  final neg = d.isNegative;
  final min = d.abs().inMinutes;
  final h = min ~/ 60;
  final m = min % 60;
  final corpo = h == 0 ? '${m}m' : '${h}h ${m.toString().padLeft(2, '0')}m';
  if (min == 0) return '0m';
  return '${neg ? '−' : '+'}$corpo';
}

String _dm(DateTime d) => '${d.day}/${d.month}';

/// O mapa de horário da semana em HTML (para afixar): uma linha por pessoa.
String mapaHorarioHtml({
  required String empresa,
  required DateTime segunda,
  required List<({String nome, List<DiaEscala> dias})> linhas,
}) {
  final domingo = DateTime(segunda.year, segunda.month, segunda.day + 6);
  final cab = StringBuffer('<tr><th>Colaborador</th>');
  for (var i = 0; i < 7; i++) {
    final d = DateTime(segunda.year, segunda.month, segunda.day + i);
    cab.write('<th>${nomesDiasCurtos[i]}<br>${_dm(d)}</th>');
  }
  cab.write('<th>Horas</th></tr>');
  final corpo = StringBuffer();
  for (final l in linhas) {
    final total = l.dias.fold(Duration.zero, (s, d) => s + d.previsto);
    corpo.write('<tr><td>${escaparHtml(l.nome)}</td>');
    for (final d in l.dias) {
      corpo.write('<td>${escaparHtml(d.texto)}</td>');
    }
    corpo.write(
      '<td class="num">${total.inMinutes ~/ 60}h ${(total.inMinutes % 60).toString().padLeft(2, '0')}m</td></tr>',
    );
  }
  return '''
<h1>Mapa de horário de trabalho</h1>
<p class="sub">${escaparHtml(empresa)} · semana de ${_dm(segunda)} a ${_dm(domingo)}/${domingo.year}</p>
<table class="horario">
$cab
$corpo
</table>
<p class="aviso">Horas = tempo de trabalho previsto (descontadas as pausas). O horário deve estar afixado em local visível.</p>
''';
}

const mapaHorarioEstilo = '''
  table.horario { max-width: 900px; }
  table.horario th, table.horario td { text-align: center; font-size: 12px; }
  table.horario td:first-child, table.horario th:first-child { text-align: left; }
  table.horario td.num { text-align: right; }
''';
