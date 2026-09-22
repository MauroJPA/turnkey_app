import '../../../core/formatting/money_provider.dart';
import '../../tech_sheets/domain/tech_sheet.dart';
import '../domain/configuracao_encomendas.dart';
import '../domain/encomenda.dart';

String nomeFicha(String fichaId, List<FichaTecnica> fichas) {
  final f = fichas.where((f) => f.id == fichaId).toList();
  return f.isEmpty ? '(produto removido)' : f.first.nome;
}

String diaSemana(DateTime d) {
  const dias = [
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo',
  ];
  return dias[d.weekday - 1];
}

String _esc(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

/// Talão para imprimir na fábrica — a data/hora em destaque grande, como
/// pedido, para ser impossível de não ver. `termico80` usa uma largura
/// estreita (impressora de recibos); `a4` usa a folha inteira.
String talaoHtml(
  Encomenda e,
  List<EncomendaItem> itens,
  List<FichaTecnica> fichas,
  String nomeEmpresa,
  TalaoTamanho tamanho,
  MoneyFmt fmt,
) {
  final largura = tamanho == TalaoTamanho.termico80 ? '80mm' : '190mm';
  final itensHtml = itens.map((it) {
    final qtd = it.quantidade.truncateToDouble() == it.quantidade
        ? it.quantidade.toStringAsFixed(0)
        : it.quantidade.toStringAsFixed(1);
    return '''
<tr>
  <td class="qtd">${_esc(qtd)}x</td>
  <td>${_esc(nomeFicha(it.fichaId, fichas))}${it.notas.isNotEmpty ? '<br><span class="nota-item">${_esc(it.notas)}</span>' : ''}</td>
</tr>''';
  }).join('\n');

  final pagamentoHtml = !e.temValor
      ? ''
      : '''
<div class="pagamento ${e.estadoPagamento == EstadoPagamento.pago ? 'pago' : ''}">
  <div class="linha"><span>Total</span><strong>${_esc(fmt(e.valorTotal))}</strong></div>
  ${e.valorPago > 0 ? '<div class="linha"><span>Pago</span><span>${_esc(fmt(e.valorPago))}</span></div>' : ''}
  <div class="linha destaque">
    <span>${e.estadoPagamento == EstadoPagamento.pago ? 'Pago na totalidade' : 'A cobrar na entrega'}</span>
    ${e.estadoPagamento == EstadoPagamento.pago ? '' : '<strong>${_esc(fmt(e.valorEmFalta))}</strong>'}
  </div>
</div>''';

  return '''
<style>
  .talao { width: $largura; margin: 0 auto; }
  .talao h1 { font-size: 16px; margin: 0 0 2px; }
  .talao .empresa { font-size: 12px; color: #555; margin: 0 0 14px; }
  .talao .datahora {
    font-size: 22px; font-weight: 700; border: 2px solid #111;
    padding: 8px; text-align: center; margin-bottom: 14px;
  }
  .talao .cliente { font-size: 14px; margin-bottom: 4px; }
  .talao .subinfo { font-size: 12px; color: #555; margin-bottom: 14px; }
  .talao table { width: 100%; border-collapse: collapse; margin-bottom: 14px; }
  .talao td { border-bottom: 1px solid #ccc; padding: 6px 2px; font-size: 13px; vertical-align: top; }
  .talao td.qtd { width: 40px; font-weight: 700; }
  .talao .nota-item { font-size: 11px; color: #555; }
  .talao .notas { font-size: 12px; border-top: 1px dashed #999; padding-top: 8px; }
  .talao .pagamento { border: 1px solid #111; padding: 8px 10px; margin-bottom: 14px; }
  .talao .pagamento.pago { border-style: dashed; }
  .talao .pagamento .linha { display: flex; justify-content: space-between; font-size: 13px; padding: 2px 0; }
  .talao .pagamento .linha.destaque { font-size: 16px; font-weight: 700; border-top: 1px solid #111; margin-top: 4px; padding-top: 6px; }
</style>
<div class="talao">
  <h1>Encomenda</h1>
  <p class="empresa">${_esc(nomeEmpresa)}</p>
  <div class="datahora">
    ${_esc(diaSemana(e.dataHora))}<br>
    ${e.dataHora.day.toString().padLeft(2, '0')}/${e.dataHora.month.toString().padLeft(2, '0')}/${e.dataHora.year}
    — ${e.dataHora.hour.toString().padLeft(2, '0')}:${e.dataHora.minute.toString().padLeft(2, '0')}
  </div>
  <p class="cliente"><strong>${_esc(e.clienteNome)}</strong></p>
  ${e.clienteTelefone.isNotEmpty ? '<p class="subinfo">${_esc(e.clienteTelefone)}</p>' : ''}
  <table>$itensHtml</table>
  $pagamentoHtml
  ${e.clienteNotas.isNotEmpty ? '<p class="notas"><strong>Cliente:</strong> ${_esc(e.clienteNotas)}</p>' : ''}
  ${e.notas.isNotEmpty ? '<p class="notas"><strong>Interno:</strong> ${_esc(e.notas)}</p>' : ''}
</div>
''';
}
