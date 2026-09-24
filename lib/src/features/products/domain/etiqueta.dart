import '../../../core/nutrition/nutrition.dart';
import 'lista_ingredientes.dart';

/// Como mostrar a declaração nutricional na etiqueta.
enum EtiquetaNutri {
  tabela('Tabela'),
  linear('Linear'),
  nenhuma('Nenhuma');

  const EtiquetaNutri(this.label);
  final String label;
}

/// Expressão da data de durabilidade.
enum EtiquetaData {
  preferencia('Consumir de preferência antes de'),
  ate('Consumir até');

  const EtiquetaData(this.texto);
  final String texto;
}

/// Tudo o que entra numa etiqueta (por omissão 50 × 80 mm: 25 mm de frente, nome e
/// descrição) e 55 mm depois da dobra (informação legal).
class EtiquetaDados {
  const EtiquetaDados({
    required this.nome,
    this.descricao = '',
    this.ingredientes,
    this.resumida = false,
    this.nutri,
    this.modoNutri = EtiquetaNutri.tabela,
    this.tracos = const [],
    this.pesoLiquidoG = 0,
    this.mostrarE = false,
    this.conservacao = '',
    required this.fabrico,
    this.validadeDias = 0,
    this.tipoData = EtiquetaData.preferencia,
    this.lote = '',
    this.produtor = '',
    this.copias = 1,
    this.larguraMm = 50,
    this.alturaFrenteMm = 25,
    this.alturaCorpoMm = 55,
  });

  final String nome;
  final String descricao;
  final ListaIngredientes? ingredientes;
  final bool resumida;

  /// Valores por 100 g (já com a perda de cozedura).
  final Nutrientes? nutri;
  final EtiquetaNutri modoNutri;

  /// Alergénios "pode conter".
  final List<String> tracos;
  final double pesoLiquidoG;

  /// Símbolo ℮ (compromisso do embalador com o peso médio — só se controlarem
  /// o peso das embalagens).
  final bool mostrarE;
  final String conservacao;
  final DateTime fabrico;
  final int validadeDias;
  final EtiquetaData tipoData;
  final String lote;
  final String produtor;
  final int copias;

  /// Largura da etiqueta.
  final int larguraMm;

  /// Altura da frente (nome, descrição e peso), até à dobra.
  final int alturaFrenteMm;

  /// Altura da parte de baixo (depois da dobra).
  final int alturaCorpoMm;

  int get alturaTotalMm => alturaFrenteMm + alturaCorpoMm;

  DateTime get validade => fabrico.add(Duration(days: validadeDias));
}

/// O que falta para a etiqueta ficar completa (lista vazia = nada a apontar).
List<String> avisosEtiqueta(EtiquetaDados d) => [
  if (d.ingredientes == null || d.ingredientes!.vazia)
    'Sem lista de ingredientes',
  if (d.produtor.trim().isEmpty) 'Falta o nome e a morada do produtor',
  if (d.pesoLiquidoG <= 0) 'Falta o peso líquido (peso por unidade da ficha)',
  if (d.validadeDias <= 0) 'Falta o prazo de validade na ficha',
  if (d.conservacao.trim().isEmpty) 'Falta o modo de conservação na ficha',
  if (d.modoNutri != EtiquetaNutri.nenhuma &&
      (d.nutri == null || d.nutri!.vazio))
    'Sem valores nutricionais (escolhe "Nenhuma" ou completa a ficha)',
];

/// Tira pontos e espaços do fim (o ponto final é posto pela etiqueta).
String _semPontoFinal(String s) =>
    s.trim().replaceFirst(RegExp(r'[.\s]+$'), '');

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _g(double v, {int casas = 1}) {
  if (v == 0) return '0';
  final s = v.toStringAsFixed(casas);
  final t = s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
  return t.replaceAll('.', ',');
}

String _data(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _energia(Nutrientes n) =>
    '${_g(n.kj, casas: 0)} kJ/${_g(n.kcal, casas: 0)} kcal';

String _nutriTabela(Nutrientes n) {
  String linha(String r, String v, {bool sub = false}) =>
      '<tr${sub ? ' class="sub"' : ''}><td>${_esc(r)}</td><td class="v">${_esc(v)}</td></tr>';
  return '''
<div class="nt">Valores nutricionais médios (referência, aproximados) por 100 g</div>
<table class="nutri">
${linha('Energia', _energia(n))}
${linha('Lípidos', '${_g(n.lipidos)} g')}
${linha('dos quais saturados', '${_g(n.saturados)} g', sub: true)}
${linha('Hidratos de carbono', '${_g(n.hidratos)} g')}
${linha('dos quais açúcares', '${_g(n.acucares)} g', sub: true)}
${linha('Fibra', '${_g(n.fibra)} g')}
${linha('Proteínas', '${_g(n.proteina)} g')}
${linha('Sal', '${_g(n.sal, casas: 2)} g')}
</table>''';
}

String _nutriLinear(Nutrientes n) =>
    '<p><b>Valores nutricionais médios (referência, aproximados) por 100 g:</b> '
    'Energia ${_esc(_energia(n))}; Lípidos ${_g(n.lipidos)} g, dos quais '
    'saturados ${_g(n.saturados)} g; Hidratos de carbono ${_g(n.hidratos)} g, '
    'dos quais açúcares ${_g(n.acucares)} g; Fibra ${_g(n.fibra)} g; '
    'Proteínas ${_g(n.proteina)} g; Sal ${_g(n.sal, casas: 2)} g.</p>';

String _ingredientesHtml(ListaIngredientes lista) {
  final b = StringBuffer('<p class="ing"><b>Ingredientes:</b> ');
  for (final s in lista.segmentos) {
    final t = _esc(s.texto);
    b.write(s.negrito ? '<b>$t</b>' : t);
  }
  b.write('.</p>');
  return b.toString();
}

String _etiquetaHtml(EtiquetaDados d, {required bool repetida}) {
  final nutri = d.nutri;
  final lista = d.ingredientes == null
      ? null
      : (d.resumida ? d.ingredientes!.resumida() : d.ingredientes!);
  final corpo = StringBuffer();
  if (d.modoNutri != EtiquetaNutri.nenhuma && nutri != null && !nutri.vazio) {
    corpo.writeln(
      d.modoNutri == EtiquetaNutri.tabela
          ? _nutriTabela(nutri)
          : _nutriLinear(nutri),
    );
  }
  if (lista != null && !lista.vazia) corpo.writeln(_ingredientesHtml(lista));
  if (d.tracos.isNotEmpty) {
    corpo.writeln('<p><b>Pode conter:</b> ${_esc(d.tracos.join(', '))}.</p>');
  }
  if (d.conservacao.trim().isNotEmpty) {
    corpo.writeln(
      '<p><b>Conservação:</b> ${_esc(_semPontoFinal(d.conservacao))}.</p>',
    );
  }
  corpo.writeln('<p><b>Fabrico:</b> ${_data(d.fabrico)}</p>');
  if (d.validadeDias > 0) {
    corpo.writeln(
      '<p><b>${_esc(d.tipoData.texto)}:</b> ${_data(d.validade)}</p>',
    );
  }
  if (d.lote.trim().isNotEmpty) {
    corpo.writeln('<p><b>Lote:</b> ${_esc(d.lote.trim())}</p>');
  }
  if (d.produtor.trim().isNotEmpty) {
    corpo.writeln(
      '<p class="prod">${_esc(d.produtor.trim()).replaceAll('\n', '<br>')}</p>',
    );
  }
  return '''
<div class="etq${repetida ? ' rep' : ''}">
<section class="topo"><h1>${_esc(d.nome)}</h1>${d.descricao.trim().isEmpty ? '' : '<p class="desc">${_esc(d.descricao.trim())}</p>'}${d.pesoLiquidoG > 0 ? '<p class="peso">Peso líquido: ${_g(d.pesoLiquidoG, casas: 0)} g${d.mostrarE ? ' ℮' : ''}</p>' : ''}</section>
<section class="corpo">
$corpo</section>
</div>''';
}

/// Página HTML completa com [EtiquetaDados.copias] etiquetas:
/// no ecrã mostra a primeira ampliada, com um botão para imprimir e avisos se
/// o texto não couber; ao imprimir, sai uma etiqueta por página.
///
/// Com [tokenMedicao], a página envia à janela que a contém as alturas
/// mínimas medidas (`etq:<token>:<frente>:<corpo>`), para a app as mostrar.
String etiquetaPagina(EtiquetaDados d, {String tokenMedicao = ''}) {
  final copias = d.copias < 1 ? 1 : d.copias;
  final etiquetas = StringBuffer();
  for (var i = 0; i < copias; i++) {
    etiquetas.writeln(_etiquetaHtml(d, repetida: i > 0));
  }
  return '''
<!DOCTYPE html>
<html lang="pt">
<head>
<meta charset="utf-8">
<title>Etiqueta — ${_esc(d.nome)}</title>
<style>
  @page { size: ${d.larguraMm}mm ${d.alturaTotalMm}mm; margin: 0; }
  * { box-sizing: border-box; }
  body { margin: 0; font-family: Arial, Helvetica, sans-serif; color: #000; }
  .etq { width: ${d.larguraMm}mm; height: ${d.alturaTotalMm}mm; overflow: hidden; background: #fff; break-after: page; page-break-after: always; position: relative; }
  .etq:last-child { break-after: auto; page-break-after: auto; }
  .topo { height: ${d.alturaFrenteMm}mm; padding: 2mm 2.5mm; overflow: hidden; text-align: center; display: flex; flex-direction: column; justify-content: center; }
  .topo h1 { font-size: 13pt; margin: 0 0 1mm; text-transform: uppercase; line-height: 1.1; }
  .topo .desc { font-size: 7.5pt; margin: 0; line-height: 1.2; }
  .topo .peso { font-size: 8pt; font-weight: bold; margin: 1.2mm 0 0; }
  .corpo { height: ${d.alturaCorpoMm}mm; padding: 1.2mm 2.5mm; overflow: hidden; font-size: 6pt; line-height: 1.15; }
  .corpo p { margin: 0 0 0.5mm; }
  .corpo .peq { font-size: 6pt; font-style: italic; }
  .corpo .nt { font-weight: bold; margin: 0 0 0.4mm; }
  table.nutri { border-collapse: collapse; width: 100%; margin-bottom: 0.6mm; }
  table.nutri td { padding: 0 0.6mm; border-top: 0.2mm solid #000; font-size: 6pt; line-height: 1.1; }
  table.nutri td.v { text-align: right; white-space: nowrap; }
  table.nutri tr.sub td:first-child { padding-left: 3mm; font-style: italic; }
  .prod { margin-top: 0.6mm; }
  .barra { display: none; }
  @media screen {
    body { background: #ddd; padding: 12px; }
    .barra { display: block; position: sticky; top: 0; background: #fff; padding: 10px 14px; margin: -12px -12px 16px; box-shadow: 0 1px 4px rgba(0,0,0,.3); z-index: 5; font-size: 14px; }
    .barra button { font-size: 15px; padding: 8px 18px; cursor: pointer; }
    .barra .aviso { color: #b00020; margin-top: 8px; }
    .etq { zoom: 4; margin: 0 auto 16px; box-shadow: 0 1px 6px rgba(0,0,0,.4); }
    .etq.rep { display: none; }
    .etq .topo { border-bottom: 0.15mm dashed #999; }
    .etq.estoira { outline: 0.4mm solid #b00020; }
  }
  @media print { .barra { display: none !important; } }
</style>
</head>
<body>
<div class="barra">
  <button onclick="window.print()">Imprimir $copias etiqueta${copias == 1 ? '' : 's'}</button>
  <span> ${d.larguraMm} × ${d.alturaTotalMm} mm · frente ${d.alturaFrenteMm} mm + ${d.alturaCorpoMm} mm depois da dobra. No diálogo: papel ${d.larguraMm} × ${d.alturaTotalMm} mm, margens nenhumas, escala 100 %.</span>
  <div id="medido"></div>
  <div class="aviso" id="aviso"></div>
</div>
$etiquetas
<script>
  (function () {
    var e = document.querySelector('.etq');
    if (!e) return;
    function mm(el) { var h = el.style.height; el.style.height = 'auto'; var v = el.offsetHeight / 3.7795; el.style.height = h; return v; }
    var t0 = e.querySelector('.topo'), c0 = e.querySelector('.corpo');
    if ('$tokenMedicao' && window.parent !== window) window.parent.postMessage('etq:$tokenMedicao:' + mm(t0).toFixed(1) + ':' + mm(c0).toFixed(1), '*');
    document.getElementById('medido').textContent = 'Mínimo medido: frente ' + Math.ceil(mm(t0)) + ' mm · parte de baixo ' + Math.ceil(mm(c0)) + ' mm.';
    var msgs = [];
    var topo = e.querySelector('.topo'), corpo = e.querySelector('.corpo');
    if (topo.scrollHeight > topo.clientHeight + 1) msgs.push('O nome/descrição não cabe nos ${d.alturaFrenteMm} mm da frente — encurta a descrição ou aumenta a altura.');
    if (corpo.scrollHeight > corpo.clientHeight + 1) msgs.push('A informação não cabe nos ${d.alturaCorpoMm} mm — usa a lista resumida, a nutrição linear ou aumenta a altura.');
    if (msgs.length) { e.classList.add('estoira'); document.getElementById('aviso').innerHTML = '⚠ ' + msgs.join('<br>⚠ '); }
  })();
</script>
</body>
</html>''';
}
