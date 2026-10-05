import '../../../core/printing/html_escape.dart';
import 'lote.dart';

String _d(DateTime? d) {
  if (d == null) return '—';
  String dois(int n) => n.toString().padLeft(2, '0');
  return '${dois(d.day)}/${dois(d.month)}/${d.year}';
}

String _q(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// Folha de rastreabilidade de um lote de produção, pronta a imprimir ou
/// guardar em PDF (Reg. (CE) n.º 178/2002, art. 18.º: o operador sabe de que
/// lotes de ingredientes e fornecedores veio cada lote que produziu).
/// Todo o texto do utilizador é escapado.
String rastreabilidadeHtml(
  LoteProducao l, {
  String empresa = '',
  String produtor = '',
}) {
  final linhas = StringBuffer();
  for (final i in l.ingredientes) {
    linhas.writeln(
      '<tr><td>${escaparHtml(i.nome)}</td>'
      '<td>${i.lote.isEmpty ? '<i>não registado</i>' : escaparHtml(i.lote)}</td>'
      '<td>${escaparHtml(i.fornecedor.isEmpty ? '—' : i.fornecedor)}</td>'
      '<td>${_d(i.validade)}</td></tr>',
    );
  }
  return '''
<h1>Ficha de rastreabilidade</h1>
<p class="sub">${escaparHtml(empresa)}${produtor.trim().isEmpty ? '' : ' · ${escaparHtml(produtor.trim())}'}</p>
<table class="meta">
<tr><th>Lote</th><td><b>${escaparHtml(l.codigo)}</b></td></tr>
<tr><th>Produto</th><td>${escaparHtml(l.fichaNome)}</td></tr>
<tr><th>Data de produção</th><td>${_d(l.dataProducao)}</td></tr>
<tr><th>Quantidade</th><td>${l.quantidade > 0 ? '${_q(l.quantidade)} un' : '—'}</td></tr>
<tr><th>Validade</th><td>${_d(l.validade)}</td></tr>
<tr><th>Responsável</th><td>${escaparHtml(l.responsavel.isEmpty ? '—' : l.responsavel)}</td></tr>
</table>
<h2>Ingredientes e lotes usados</h2>
<table>
<tr><th>Ingrediente</th><th>Lote do fornecedor</th><th>Fornecedor</th><th>Validade</th></tr>
$linhas</table>
${l.notas.trim().isEmpty ? '' : '<p><b>Notas:</b> ${escaparHtml(l.notas)}</p>'}
<p class="aviso">Registo para efeitos de rastreabilidade (Reg. (CE) n.º 178/2002, art. 18.º). ${l.semLote > 0 ? '${l.semLote} ingrediente(s) sem lote registado. ' : ''}Conservar durante, pelo menos, o prazo de validade do produto.</p>
''';
}

/// CSS extra para a folha (usa o `abrirImpressao`).
const rastreabilidadeEstilo = '''
  h1 { font-size: 20px; }
  h2 { font-size: 15px; margin: 18px 0 6px; }
  table { max-width: none; }
  table.meta th { width: 38%; text-align: left; background: #f3f3f3; }
  table.meta td { text-align: left; }
  th { text-align: left; }
''';
