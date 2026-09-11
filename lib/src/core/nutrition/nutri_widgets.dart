import 'package:flutter/material.dart';

import 'nutrition.dart';

String _g(double v, {int casas = 1}) {
  if (v == 0) return '0';
  final s = v.toStringAsFixed(casas);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s.replaceAll('.', ',');
}

/// As 8 linhas da declaração nutricional da UE, com nomes e unidades.
List<({String rotulo, String Function(Nutrientes) valor, bool indent})>
    get _linhas => [
          (
            rotulo: 'Energia',
            valor: (n) => '${_g(n.kj, casas: 0)} kJ / ${_g(n.kcal, casas: 0)} kcal',
            indent: false
          ),
          (rotulo: 'Lípidos', valor: (n) => '${_g(n.lipidos)} g', indent: false),
          (
            rotulo: 'dos quais saturados',
            valor: (n) => '${_g(n.saturados)} g',
            indent: true
          ),
          (
            rotulo: 'Hidratos de carbono',
            valor: (n) => '${_g(n.hidratos)} g',
            indent: false
          ),
          (
            rotulo: 'dos quais açúcares',
            valor: (n) => '${_g(n.acucares)} g',
            indent: true
          ),
          (rotulo: 'Fibra', valor: (n) => '${_g(n.fibra)} g', indent: false),
          (
            rotulo: 'Proteínas',
            valor: (n) => '${_g(n.proteina)} g',
            indent: false
          ),
          (rotulo: 'Sal', valor: (n) => '${_g(n.sal, casas: 2)} g', indent: false),
        ];

/// Tabela da declaração nutricional. Uma ou duas colunas de valores.
class NutriTabela extends StatelessWidget {
  const NutriTabela({
    super.key,
    required this.col1Titulo,
    required this.col1,
    this.col2Titulo,
    this.col2,
  });

  final String col1Titulo;
  final Nutrientes col1;
  final String? col2Titulo;
  final Nutrientes? col2;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final duas = col2 != null;
    return Table(
      border: TableBorder(
        horizontalInside: BorderSide(color: cs.outlineVariant, width: .5),
      ),
      columnWidths: duas
          ? const {0: FlexColumnWidth(2.4), 1: FlexColumnWidth(1.6), 2: FlexColumnWidth(1.6)}
          : const {0: FlexColumnWidth(2.4), 1: FlexColumnWidth(1.6)},
      children: [
        TableRow(
          decoration: BoxDecoration(color: cs.surfaceContainerHighest),
          children: [
            const _Cel('', bold: true),
            _Cel(col1Titulo, bold: true, alignEnd: true),
            if (duas) _Cel(col2Titulo ?? '', bold: true, alignEnd: true),
          ],
        ),
        for (final l in _linhas)
          TableRow(children: [
            _Cel(l.rotulo, indent: l.indent),
            _Cel(l.valor(col1), alignEnd: true),
            if (duas) _Cel(l.valor(col2!), alignEnd: true),
          ]),
      ],
    );
  }
}

class _Cel extends StatelessWidget {
  const _Cel(this.t,
      {this.bold = false, this.indent = false, this.alignEnd = false});
  final String t;
  final bool bold;
  final bool indent;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(indent ? 16 : 6, 6, 6, 6),
        child: Text(
          t,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
            fontStyle: indent ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      );
}

/// "Contém: X, Y. Pode conter: Z." (vazio se não houver nada).
String alergeniosResumo(List<String> contem, List<String> tracos) {
  final p = <String>[];
  if (contem.isNotEmpty) p.add('Contém: ${contem.join(', ')}.');
  if (tracos.isNotEmpty) p.add('Pode conter: ${tracos.join(', ')}.');
  return p.join(' ');
}

/// Declaração nutricional em texto simples (para copiar / imprimir).
String declaracaoTexto({
  required String titulo,
  required Nutrientes por100g,
  Nutrientes? porUnidade,
  double pesoUnidadeG = 0,
  required List<String> alergenios,
  required List<String> alergeniosTracos,
  bool completo = true,
}) {
  final b = StringBuffer();
  b.writeln('DECLARAÇÃO NUTRICIONAL — $titulo');
  b.writeln('');
  final col1 = 'por 100 g';
  final col2 = porUnidade != null
      ? 'por unidade${pesoUnidadeG > 0 ? ' (${_g(pesoUnidadeG, casas: 0)} g)' : ''}'
      : null;
  b.writeln(col2 != null ? '$col1   |   $col2' : col1);
  for (final l in _linhas) {
    final v1 = l.valor(por100g);
    final v2 = porUnidade != null ? l.valor(porUnidade) : null;
    b.writeln('${l.indent ? '  ' : ''}${l.rotulo}: $v1${v2 != null ? '   |   $v2' : ''}');
  }
  final al = alergeniosResumo(alergenios, alergeniosTracos);
  if (al.isNotEmpty) {
    b.writeln('');
    b.writeln(al);
  }
  if (!completo) {
    b.writeln('');
    b.writeln('(!) Valores incompletos — há ingredientes sem informação '
        'nutricional.');
  }
  return b.toString();
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

/// Declaração nutricional em HTML simples — corpo de página para
/// [abrirImpressao] (`core/printing/print_html.dart`). Visual provisório;
/// será substituído por um template a fornecer.
String declaracaoHtml({
  required String titulo,
  required Nutrientes por100g,
  Nutrientes? porUnidade,
  double pesoUnidadeG = 0,
  required List<String> alergenios,
  required List<String> alergeniosTracos,
  bool completo = true,
}) {
  final col2Titulo = porUnidade != null
      ? 'por unidade${pesoUnidadeG > 0 ? ' (${_g(pesoUnidadeG, casas: 0)} g)' : ''}'
      : null;
  final linhas = StringBuffer();
  for (final l in _linhas) {
    final v1 = l.valor(por100g);
    final v2 = porUnidade != null ? l.valor(porUnidade) : null;
    linhas.writeln(
      '<tr><td class="${l.indent ? 'indent' : ''}">${_esc(l.rotulo)}</td>'
      '<td class="valor">${_esc(v1)}</td>'
      '${v2 != null ? '<td class="valor">${_esc(v2)}</td>' : ''}</tr>',
    );
  }
  final al = alergeniosResumo(alergenios, alergeniosTracos);
  return '''
<h1>Declaração nutricional</h1>
<p class="sub">${_esc(titulo)}</p>
<table>
<tr><th></th><th>por 100 g</th>${col2Titulo != null ? '<th>${_esc(col2Titulo)}</th>' : ''}</tr>
$linhas
</table>
${al.isNotEmpty ? '<p class="alergenios">${_esc(al)}</p>' : ''}
${!completo ? '<p class="aviso">(!) Valores incompletos — há ingredientes sem informação nutricional.</p>' : ''}
<p class="aviso">Cálculo a partir dos valores dos ingredientes (Reg. (UE) 1169/2011). Confirma com os rótulos.</p>
''';
}
