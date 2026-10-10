import '../../../core/printing/html_escape.dart';
import '../../pricing/domain/canal_venda.dart';
import '../../pricing/domain/cost_config.dart';
import '../../tech_sheets/domain/tech_sheet.dart';

/// Um degrau de desconto por volume: a partir de [minUn] unidades (de um
/// mesmo produto) o preço baixa [pct] %.
class EscalaDesconto {
  const EscalaDesconto(this.minUn, this.pct);

  final int minUn;
  final double pct;

  @override
  bool operator ==(Object other) =>
      other is EscalaDesconto && other.minUn == minUn && other.pct == pct;

  @override
  int get hashCode => Object.hash(minUn, pct);
}

/// "24:5;48:10" → [24 un −5 %, 48 un −10 %]. Ignora o que não se entende e
/// devolve ordenado por quantidade (sem repetidos).
List<EscalaDesconto> lerEscalas(String? texto) {
  final out = <int, EscalaDesconto>{};
  for (final parte in (texto ?? '').split(';')) {
    final p = parte.split(':');
    if (p.length != 2) continue;
    final q = int.tryParse(p[0].trim());
    final d = double.tryParse(p[1].trim().replaceAll(',', '.'));
    if (q == null || d == null || q < 2 || d <= 0 || d >= 100) continue;
    out[q] = EscalaDesconto(q, d);
  }
  return out.values.toList()..sort((a, b) => a.minUn.compareTo(b.minUn));
}

String escreverEscalas(List<EscalaDesconto> e) =>
    [for (final x in e) '${x.minUn}:${x.pct}'].join(';');

/// Arredonda a cêntimos.
double centimos(double v) => (v * 100).round() / 100;

/// Uma linha da tabela de preços: o preço de revenda de um produto e os
/// preços com desconto por volume (tudo arredondado a cêntimos).
class LinhaTabela {
  const LinhaTabela({
    required this.ficha,
    required this.precoSemIva,
    required this.precoComIva,
    required this.escalas,
  });

  final FichaTecnica ficha;

  /// Preço por unidade para o revendedor, sem IVA.
  final double precoSemIva;

  /// O mesmo com IVA (0 % de IVA = igual ao [precoSemIva]).
  final double precoComIva;

  /// Preço sem IVA em cada degrau, pela ordem das escalas.
  final List<double> escalas;

  String get nome =>
      ficha.subnome.isEmpty ? ficha.nome : '${ficha.nome} · ${ficha.subnome}';
}

/// De onde sai o preço do revendedor.
///
/// O preço de referência é o de venda ao público (sem IVA). O revendedor paga
/// esse preço menos o [descontoPct]; ou, com [canal], o que **nos chega** desse
/// canal (as taxas do revendedor/plataforma já tiradas) — assim a tabela diz
/// o mesmo que a conta de rentabilidade.
double precoRevenda(
  double precoPublicoSemIva, {
  double descontoPct = 0,
  CanalVenda? canal,
}) {
  final base = canal == null
      ? precoPublicoSemIva * (1 - descontoPct / 100)
      : canal.aoPreco(precoPublicoSemIva).receita;
  return centimos(base < 0 ? 0 : base);
}

/// A tabela de preços de revenda de [fichas] (só as que têm preço de venda),
/// por ordem de categoria e nome.
List<LinhaTabela> calcularTabela({
  required List<FichaTecnica> fichas,
  required CostConfig config,
  double descontoPct = 0,
  CanalVenda? canal,
  List<EscalaDesconto> escalas = const [],
  Set<String> excluidos = const {},
}) {
  final out = <LinhaTabela>[];
  for (final f in fichas) {
    if (f.deletado || !f.temPrecoVenda || excluidos.contains(f.id)) continue;
    // cada produto com o seu IVA (ex.: bebidas de revenda)
    final c = f.ivaProduto == null
        ? config
        : config.copyWith(ivaVendas: f.ivaProduto);
    final publico = c.semIva(f.precoVenda);
    final base = precoRevenda(publico, descontoPct: descontoPct, canal: canal);
    out.add(
      LinhaTabela(
        ficha: f,
        precoSemIva: base,
        precoComIva: centimos(c.comIva(base)),
        escalas: [for (final e in escalas) centimos(base * (1 - e.pct / 100))],
      ),
    );
  }
  out.sort((a, b) {
    final c = a.ficha.categoria.compareTo(b.ficha.categoria);
    return c != 0 ? c : a.ficha.nome.compareTo(b.ficha.nome);
  });
  return out;
}

String _data(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _n(double v) => v == v.roundToDouble()
    ? v.toStringAsFixed(0)
    : v.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll('.', ',');

/// A tabela em texto simples, pronta a colar no WhatsApp (`*negrito*`).
String tabelaTexto({
  required List<LinhaTabela> linhas,
  required List<EscalaDesconto> escalas,
  required double ivaPct,
  required String empresa,
  required String Function(double) fmt,
  required DateTime data,
}) {
  final b = StringBuffer()
    ..writeln('*${empresa.isEmpty ? 'Tabela de preços' : empresa}*')
    ..writeln('Tabela de preços ${_data(data)}')
    ..writeln(
      ivaPct > 0
          ? 'Preços por unidade, sem IVA (IVA ${_n(ivaPct)} % acrescido).'
          : 'Preços por unidade.',
    );
  String? cat;
  for (final l in linhas) {
    if (l.ficha.categoria != cat) {
      cat = l.ficha.categoria;
      if (cat.isNotEmpty) b.writeln('\n*$cat*');
    }
    final iva = ivaPct > 0 ? ' (${fmt(l.precoComIva)} c/IVA)' : '';
    b.writeln('• ${l.nome}: ${fmt(l.precoSemIva)}$iva');
  }
  if (escalas.isNotEmpty) {
    b
      ..writeln('\n*Desconto por quantidade* (por produto)')
      ..writeln(
        escalas
            .map((e) => '• ${e.minUn}+ unidades: −${_n(e.pct)} %')
            .join('\n'),
      );
  }
  return b.toString().trimRight();
}

/// O corpo HTML da tabela para [abrirImpressao] (PDF pelo navegador).
String tabelaHtml({
  required List<LinhaTabela> linhas,
  required List<EscalaDesconto> escalas,
  required double ivaPct,
  required String empresa,
  required String Function(double) fmt,
  required DateTime data,
}) {
  final temIva = ivaPct > 0;
  final cabecalho = StringBuffer()
    ..write('<tr><th class="esq">Produto</th><th>Preço s/IVA</th>');
  if (temIva) cabecalho.write('<th>Preço c/IVA</th>');
  for (final e in escalas) {
    cabecalho.write('<th>${e.minUn}+ un<br>−${_n(e.pct)} %</th>');
  }
  cabecalho.write('</tr>');
  final colunas = 2 + (temIva ? 1 : 0) + escalas.length;

  final corpo = StringBuffer();
  String? cat;
  for (final l in linhas) {
    if (l.ficha.categoria != cat) {
      cat = l.ficha.categoria;
      if (cat.isNotEmpty) {
        corpo.write(
          '<tr><td class="cat" colspan="$colunas">${escaparHtml(cat)}</td></tr>',
        );
      }
    }
    corpo.write('<tr><td class="esq">${escaparHtml(l.nome)}</td>');
    corpo.write('<td>${escaparHtml(fmt(l.precoSemIva))}</td>');
    if (temIva) corpo.write('<td>${escaparHtml(fmt(l.precoComIva))}</td>');
    for (final p in l.escalas) {
      corpo.write('<td>${escaparHtml(fmt(p))}</td>');
    }
    corpo.write('</tr>');
  }

  return '''
<h1>${escaparHtml(empresa.isEmpty ? 'Tabela de preços' : empresa)}</h1>
<p class="sub">Tabela de preços para revendedores · ${_data(data)}</p>
<table class="tabela">
$cabecalho
$corpo
</table>
<p class="aviso">${temIva ? 'Preços por unidade; o IVA de ${_n(ivaPct)} % está indicado na coluna «c/IVA». ' : 'Preços por unidade. '}${escalas.isEmpty ? '' : 'O desconto por quantidade aplica-se por produto. '}Preços sujeitos a alteração.</p>
''';
}

const tabelaEstilo = '''
  table.tabela { max-width: 760px; }
  table.tabela th, table.tabela td { text-align: right; }
  table.tabela th.esq, table.tabela td.esq { text-align: left; }
  table.tabela td.cat { background: #f4f4f4; font-weight: bold; text-align: left; }
''';
