import '../../../core/printing/html_escape.dart';

/// O tipo de ausência.
enum TipoAusencia {
  ferias('ferias', 'Férias'),
  baixa('baixa', 'Baixa'),
  falta('falta', 'Falta'),
  outro('outro', 'Outro');

  const TipoAusencia(this.api, this.label);
  final String api;
  final String label;

  static TipoAusencia fromApi(String? v) => TipoAusencia.values.firstWhere(
    (t) => t.api == v,
    orElse: () => TipoAusencia.ferias,
  );
}

enum EstadoAusencia {
  pedido('pedido', 'Por aprovar'),
  aprovado('aprovado', 'Aprovado'),
  recusado('recusado', 'Recusado');

  const EstadoAusencia(this.api, this.label);
  final String api;
  final String label;

  static EstadoAusencia fromApi(String? v) => EstadoAusencia.values.firstWhere(
    (t) => t.api == v,
    orElse: () => EstadoAusencia.pedido,
  );
}

DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);

/// Uma ausência (férias, baixa, falta…) de uma pessoa, de [de] a [ate] (inclusive).
class Ausencia {
  const Ausencia({
    required this.id,
    required this.pessoa,
    required this.nome,
    required this.tipo,
    required this.de,
    required this.ate,
    required this.estado,
    this.diasUteis = 0,
    this.notas = '',
  });

  final String id;
  final String pessoa;
  final String nome;
  final TipoAusencia tipo;
  final DateTime de;
  final DateTime ate;
  final EstadoAusencia estado;
  final int diasUteis;
  final String notas;

  bool cobre(DateTime dia) {
    final x = _d(dia);
    return !x.isBefore(_d(de)) && !x.isAfter(_d(ate));
  }

  bool get conta => estado != EstadoAusencia.recusado;
}

/// A Páscoa de [ano] (calendário gregoriano).
DateTime pascoa(int ano) {
  final a = ano % 19;
  final b = ano ~/ 100;
  final c = ano % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final mes = (h + l - 7 * m + 114) ~/ 31;
  final dia = ((h + l - 7 * m + 114) % 31) + 1;
  return DateTime(ano, mes, dia);
}

/// Os feriados nacionais de Portugal em [ano] (sem os municipais, nem o
/// Carnaval, que é só tolerância).
Set<DateTime> feriadosNacionais(int ano) {
  final p = pascoa(ano);
  return {
    DateTime(ano, 1, 1),
    p.subtract(const Duration(days: 2)), // Sexta-feira Santa
    p, // Páscoa
    DateTime(ano, 4, 25),
    DateTime(ano, 5, 1),
    p.add(const Duration(days: 60)), // Corpo de Deus
    DateTime(ano, 6, 10),
    DateTime(ano, 8, 15),
    DateTime(ano, 10, 5),
    DateTime(ano, 11, 1),
    DateTime(ano, 12, 1),
    DateTime(ano, 12, 8),
    DateTime(ano, 12, 25),
  };
}

/// Dias úteis entre [de] e [ate] (inclusive): segunda a sexta, sem feriados
/// nacionais — é assim que a lei conta as férias.
int diasUteisEntre(DateTime de, DateTime ate) {
  var d = _d(de);
  final fim = _d(ate);
  if (fim.isBefore(d)) return 0;
  final feriados = <int, Set<DateTime>>{};
  var n = 0;
  while (!d.isAfter(fim)) {
    final f = feriados.putIfAbsent(d.year, () => feriadosNacionais(d.year));
    if (d.weekday <= DateTime.friday && !f.contains(d)) n++;
    d = DateTime(d.year, d.month, d.day + 1);
  }
  return n;
}

/// O saldo de férias de uma pessoa num ano.
class SaldoFerias {
  const SaldoFerias({
    required this.direito,
    required this.gozados,
    required this.pedidos,
  });

  /// Dias úteis a que tem direito nesse ano.
  final int direito;

  /// Férias aprovadas (dias úteis dentro do ano).
  final int gozados;

  /// Férias pedidas e ainda por aprovar.
  final int pedidos;

  int get restam => direito - gozados - pedidos;
}

/// Os dias úteis de [a] que caem em [ano].
int diasUteisNoAno(Ausencia a, int ano) {
  final ini = DateTime(ano, 1, 1);
  final fim = DateTime(ano, 12, 31);
  final de = _d(a.de).isBefore(ini) ? ini : _d(a.de);
  final ate = _d(a.ate).isAfter(fim) ? fim : _d(a.ate);
  return diasUteisEntre(de, ate);
}

SaldoFerias calcularSaldo({
  required int direito,
  required Iterable<Ausencia> ausencias,
  required int ano,
}) {
  var gozados = 0;
  var pedidos = 0;
  for (final a in ausencias) {
    if (a.tipo != TipoAusencia.ferias) continue;
    final d = diasUteisNoAno(a, ano);
    if (a.estado == EstadoAusencia.aprovado) gozados += d;
    if (a.estado == EstadoAusencia.pedido) pedidos += d;
  }
  return SaldoFerias(direito: direito, gozados: gozados, pedidos: pedidos);
}

/// Direito a férias por omissão (Código do Trabalho, art. 238.º): 22 dias úteis.
const direitoFeriasPadrao = 22;

/// Há alguma ausência (pedida ou aprovada) da pessoa que se sobreponha a
/// [de]–[ate]? [ignorar] é o id de uma ausência que se está a editar.
Ausencia? ausenciaSobreposta(
  Iterable<Ausencia> existentes, {
  required String pessoa,
  required DateTime de,
  required DateTime ate,
  String? ignorar,
}) {
  for (final a in existentes) {
    if (a.pessoa != pessoa || !a.conta || a.id == ignorar) continue;
    if (!_d(de).isAfter(_d(a.ate)) && !_d(ate).isBefore(_d(a.de))) return a;
  }
  return null;
}

/// Quem está de férias (aprovadas) em [dia].
List<Ausencia> ausentesNoDia(Iterable<Ausencia> todas, DateTime dia) => [
  for (final a in todas)
    if (a.estado == EstadoAusencia.aprovado && a.cobre(dia)) a,
];

String _dm(DateTime d) => '${d.day}/${d.month}';

/// Texto do período: "5/1 a 20/1" (ou só "5/1").
String periodoTexto(Ausencia a) =>
    _d(a.de) == _d(a.ate) ? _dm(a.de) : '${_dm(a.de)} a ${_dm(a.ate)}';

/// O "mapa de férias" do ano em HTML (para imprimir/guardar em PDF): uma linha
/// por pessoa com os períodos aprovados e o total de dias úteis.
String mapaFeriasHtml({
  required int ano,
  required String empresa,
  required List<Ausencia> ausencias,
}) {
  final porPessoa = <String, List<Ausencia>>{};
  for (final a in ausencias) {
    if (a.tipo != TipoAusencia.ferias || a.estado != EstadoAusencia.aprovado) {
      continue;
    }
    porPessoa.putIfAbsent(a.nome, () => []).add(a);
  }
  final nomes = porPessoa.keys.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  final linhas = StringBuffer();
  for (final n in nomes) {
    final lista = porPessoa[n]!..sort((a, b) => a.de.compareTo(b.de));
    final total = lista.fold<int>(0, (s, a) => s + diasUteisNoAno(a, ano));
    linhas.write(
      '<tr><td>${escaparHtml(n)}</td>'
      '<td>${escaparHtml(lista.map(periodoTexto).join(' · '))}</td>'
      '<td class="num">$total</td></tr>',
    );
  }
  return '''
<h1>Mapa de férias $ano</h1>
<p class="sub">${escaparHtml(empresa)}</p>
<table class="mapa">
<tr><th>Colaborador</th><th>Períodos de férias</th><th>Dias úteis</th></tr>
$linhas
</table>
<p class="aviso">Dias úteis: segunda a sexta, sem feriados nacionais. O mapa de férias deve ser afixado nos locais de trabalho entre 15 de abril e 31 de outubro.</p>
''';
}

const mapaFeriasEstilo = '''
  table.mapa { max-width: 760px; }
  table.mapa th, table.mapa td { text-align: left; }
  table.mapa td.num { text-align: right; }
''';
