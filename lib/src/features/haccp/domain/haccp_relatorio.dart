import '../../../core/printing/html_escape.dart';
import 'haccp.dart';

String _d2(int n) => n.toString().padLeft(2, '0');
String _dmy(DateTime d) => '${_d2(d.day)}/${_d2(d.month)}/${d.year}';
String _hm(DateTime d) => '${_d2(d.hour)}:${_d2(d.minute)}';
String _dh(DateTime d) => '${_dmy(d)} ${_hm(d)}';

String _n(double v) =>
    (v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1)).replaceAll(
      '.',
      ',',
    );

DateTime _dia(DateTime d) => DateTime(d.year, d.month, d.day);

/// Quantos registos eram esperados num período (dias inclusive) para um
/// controlo: os diários contam todos os dias × as vezes por dia; os outros,
/// um por cada período completo (semanal: 4 num mês). Ocasionais: nenhum.
int esperadosNoPeriodo(ControloHaccp c, DateTime desde, DateTime ate) {
  if (c.periodicidadeDias <= 0) return 0;
  final dias = _dia(ate).difference(_dia(desde)).inDays + 1;
  if (dias <= 0) return 0;
  if (c.periodicidadeDias == 1) return dias * c.esperadosPorDia;
  return dias ~/ c.periodicidadeDias;
}

/// "Impressão digital" (FNV-1a de 64 bits, em hexadecimal) dos registos de um
/// relatório. Sai impressa no documento e fica guardada na emissão: se os
/// dados mudarem depois, o código já não bate certo. Não é uma assinatura
/// digital — é uma verificação de integridade.
String integridadeHaccp(List<RegistoHaccp> registos) {
  final ordenados = [...registos]..sort((a, b) => a.id.compareTo(b.id));
  final b = StringBuffer();
  for (final r in ordenados) {
    b.write(
      '${r.id}|${r.controloId}|${r.dataHora.toUtc().toIso8601String()}|'
      '${r.valor ?? ''}|${r.conforme}|${r.responsavel}|${r.notas}|'
      '${r.acaoCorretiva}|${r.resolvido}|'
      '${r.proximoVencimento?.toIso8601String() ?? ''}\n',
    );
  }
  var h = BigInt.parse('cbf29ce484222325', radix: 16);
  final primo = BigInt.parse('100000001b3', radix: 16);
  final mascara = (BigInt.one << 64) - BigInt.one;
  for (final c in b.toString().codeUnits) {
    h = ((h ^ BigInt.from(c & 0xff)) * primo) & mascara;
    if (c > 0xff) {
      h = ((h ^ BigInt.from(c >> 8)) * primo) & mascara;
    }
  }
  return h.toRadixString(16).padLeft(16, '0').toUpperCase();
}

/// O tipo de relatório: `null` = todos os tipos.
String tituloTipoRelatorio(TipoControlo? t) => switch (t) {
  null => 'Todos os controlos',
  TipoControlo.temperatura => 'Controlo de temperaturas',
  TipoControlo.limpeza => 'Higienização e limpeza',
  TipoControlo.praga => 'Controlo de pragas',
  TipoControlo.manutencao => 'Manutenção, equipamentos e validades',
  TipoControlo.outro => 'Outros registos (lotes e rastreabilidade)',
};

/// Referências legais mostradas no cabeçalho do relatório.
const enquadramentoLegalHaccp = [
  'Regulamento (CE) n.º 852/2004, relativo à higiene dos géneros alimentícios — art. 5.º '
      '(procedimentos baseados nos princípios HACCP e conservação dos documentos e registos).',
  'Regulamento (CE) n.º 178/2002 — art. 18.º (rastreabilidade).',
  'Decreto-Lei n.º 113/2006, de 12 de junho (execução em Portugal dos regulamentos '
      'comunitários de higiene dos géneros alimentícios).',
];

/// Dados de um relatório (já filtrados para o período e o tipo).
class RelatorioHaccp {
  RelatorioHaccp({
    required this.codigo,
    required this.empresa,
    required this.operador,
    required this.desde,
    required this.ate,
    required this.tipo,
    required this.controlos,
    required this.registos,
    required this.emitidoEm,
    this.emitidoPor = '',
  });

  /// Número do documento, ex. `HACCP-2026-0007`.
  final String codigo;
  final String empresa;

  /// Nome e morada do operador, como está nas definições (etiquetas).
  final String operador;
  final DateTime desde;
  final DateTime ate;
  final TipoControlo? tipo;
  final List<ControloHaccp> controlos;
  final List<RegistoHaccp> registos;
  final DateTime emitidoEm;
  final String emitidoPor;

  String get integridade => integridadeHaccp(registos);
  int get naoConformidades => registos.where((r) => !r.conforme).length;
}

/// HTML do relatório HACCP, em formato de documento para impressão ou PDF
/// (A4). Um quadro por controlo, agrupados por tipo, com a lista de
/// não conformidades, a cobertura (registos feitos vs esperados), o espaço
/// para assinatura do responsável e o código de integridade.
String haccpRelatorioLegalHtml(RelatorioHaccp r) {
  final b = StringBuffer();
  String e(String s) => escaparHtml(s);

  final porControlo = <String, List<RegistoHaccp>>{};
  for (final x in r.registos) {
    porControlo.putIfAbsent(x.controloId, () => []).add(x);
  }
  for (final l in porControlo.values) {
    l.sort((a, b) => a.dataHora.compareTo(b.dataHora));
  }
  final controlosDoRelatorio = [
    for (final c in r.controlos)
      if (r.tipo == null || c.tipo == r.tipo) c,
  ];

  // --- cabeçalho ---------------------------------------------------------------
  b.writeln('<div class="topo">');
  b.writeln('<h1>Registo de controlo de segurança alimentar (HACCP)</h1>');
  b.writeln('<p class="sub">${e(tituloTipoRelatorio(r.tipo))}</p>');
  b.writeln('</div>');
  b.writeln('<table class="ficha">');
  b.writeln('<tr><th>N.º do documento</th><td><b>${e(r.codigo)}</b></td>'
      '<th>Período</th><td>${_dmy(r.desde)} a ${_dmy(r.ate)}</td></tr>');
  b.writeln('<tr><th>Operador / estabelecimento</th><td colspan="3">'
      '${e(r.operador.isEmpty ? r.empresa : r.operador).replaceAll('\n', '<br>')}</td></tr>');
  b.writeln('<tr><th>Emitido em</th><td>${_dh(r.emitidoEm)}</td>'
      '<th>Emitido por</th><td>${e(r.emitidoPor)}</td></tr>');
  b.writeln('</table>');

  // --- resumo --------------------------------------------------------------------
  final total = r.registos.length;
  final nc = r.naoConformidades;
  final abertas = r.registos.where((x) => x.abertaNaoConformidade).length;
  var esperadosTotal = 0;
  var feitosTotal = 0;
  for (final c in controlosDoRelatorio) {
    final esp = esperadosNoPeriodo(c, r.desde, r.ate);
    final feitos = porControlo[c.id]?.length ?? 0;
    esperadosTotal += esp;
    feitosTotal += feitos > esp && esp > 0 ? esp : feitos;
  }
  b.writeln('<h2>Resumo</h2>');
  b.writeln('<table class="resumo"><tr>'
      '<td><b>$total</b><br>registos</td>'
      '<td><b>${total - nc}</b><br>conformes</td>'
      '<td class="${nc > 0 ? 'nc' : ''}"><b>$nc</b><br>não conformidades</td>'
      '<td class="${abertas > 0 ? 'nc' : ''}"><b>$abertas</b><br>por resolver</td>'
      '<td><b>${esperadosTotal == 0 ? '—' : '${(feitosTotal * 100 / esperadosTotal).round()}%'}</b>'
      '<br>cobertura ($feitosTotal de $esperadosTotal esperados)</td>'
      '</tr></table>');

  if (controlosDoRelatorio.isEmpty) {
    b.writeln('<p>Não há controlos deste tipo definidos.</p>');
  }

  // --- um quadro por controlo, por tipo -----------------------------------------------
  var secao = 0;
  for (final tipo in TipoControlo.values) {
    final doTipo = [
      for (final c in controlosDoRelatorio)
        if (c.tipo == tipo) c,
    ];
    if (doTipo.isEmpty) continue;
    secao++;
    b.writeln('<h2>$secao. ${e(tituloTipoRelatorio(tipo))}</h2>');
    for (final c in doTipo) {
      final regs = porControlo[c.id] ?? const <RegistoHaccp>[];
      final esp = esperadosNoPeriodo(c, r.desde, r.ate);
      b.writeln('<h3>${e(c.nome)}</h3>');
      b.writeln(
        '<p class="meta">Frequência: ${e(c.periodicidadeTexto)}'
        '${c.local.isEmpty ? '' : ' · Local: ${e(c.local)}'}'
        '${c.limitesTexto.isEmpty ? '' : ' · Limite crítico: <b>${e(c.limitesTexto)}</b>'}'
        ' · Registos: ${regs.length}${esp > 0 ? ' de $esp esperados' : ''}</p>',
      );
      if (c.medeValor && regs.any((x) => x.valor != null)) {
        final vals = [
          for (final x in regs)
            if (x.valor != null) x.valor!,
        ];
        final media = vals.reduce((a, b) => a + b) / vals.length;
        final u = c.unidade.isEmpty ? '°C' : c.unidade;
        b.writeln(
          '<p class="meta">Mínimo ${_n(vals.reduce((a, b) => a < b ? a : b))} $u · '
          'Máximo ${_n(vals.reduce((a, b) => a > b ? a : b))} $u · '
          'Média ${_n(media)} $u</p>',
        );
      }
      if (regs.isEmpty) {
        b.writeln('<p class="vazio">Sem registos neste período.</p>');
        continue;
      }
      b.writeln('<table class="reg"><tr><th>Data</th><th>Hora</th>'
          '${c.medeValor ? '<th>Valor</th>' : ''}'
          '<th>Conforme</th><th>Registado por</th>'
          '<th>Observações / ação corretiva</th></tr>');
      for (final x in regs) {
        final obs = [
          if (x.notas.isNotEmpty) x.notas,
          if (x.acaoCorretiva.isNotEmpty) 'Ação corretiva: ${x.acaoCorretiva}',
          if (x.proximoVencimento != null)
            'Próxima revisão/validade: ${_dmy(x.proximoVencimento!)}',
          if (!x.conforme) x.resolvido ? '(resolvida)' : '(por resolver)',
        ].join(' · ');
        final u = c.unidade.isEmpty ? '°C' : c.unidade;
        b.writeln(
          '<tr${x.conforme ? '' : ' class="nc"'}>'
          '<td>${_dmy(x.dataHora)}</td><td>${_hm(x.dataHora)}</td>'
          '${c.medeValor ? '<td>${x.valor == null ? '' : '${_n(x.valor!)} $u'}</td>' : ''}'
          '<td>${x.conforme ? 'Sim' : 'NÃO'}</td>'
          '<td>${e(x.responsavel)}</td><td>${e(obs)}</td></tr>',
        );
      }
      b.writeln('</table>');
    }
  }

  // --- não conformidades -------------------------------------------------------------------
  final ncs = [
    for (final x in r.registos)
      if (!x.conforme) x,
  ]..sort((a, b) => a.dataHora.compareTo(b.dataHora));
  b.writeln('<h2>${secao + 1}. Não conformidades e ações corretivas</h2>');
  if (ncs.isEmpty) {
    b.writeln('<p>Não houve não conformidades no período.</p>');
  } else {
    final nomes = {for (final c in r.controlos) c.id: c.nome};
    b.writeln('<table class="reg"><tr><th>Data</th><th>Controlo</th>'
        '<th>Desvio</th><th>Ação corretiva</th><th>Estado</th></tr>');
    for (final x in ncs) {
      final c = r.controlos.where((c) => c.id == x.controloId).firstOrNull;
      final desvio = x.valor != null && c != null && c.medeValor
          ? '${_n(x.valor!)} ${c.unidade.isEmpty ? '°C' : c.unidade}'
                '${c.limitesTexto.isEmpty ? '' : ' (limite ${c.limitesTexto})'}'
          : x.notas;
      b.writeln(
        '<tr class="nc"><td>${_dh(x.dataHora)}</td>'
        '<td>${e(nomes[x.controloId] ?? '')}</td><td>${e(desvio)}</td>'
        '<td>${e(x.acaoCorretiva)}</td>'
        '<td>${x.resolvido ? 'Resolvida' : 'Por resolver'}</td></tr>',
      );
    }
    b.writeln('</table>');
  }

  // --- enquadramento, assinaturas e integridade --------------------------------------------
  b.writeln('<h2>Enquadramento e validação</h2>');
  b.writeln('<ul class="lei">');
  for (final l in enquadramentoLegalHaccp) {
    b.writeln('<li>${e(l)}</li>');
  }
  b.writeln('</ul>');
  b.writeln(
    '<p class="nota">Este documento é o registo dos controlos efetuados no período, '
    'emitido a partir da aplicação. A sua adequação como evidência depende do plano HACCP '
    'do estabelecimento (análise de perigos, pontos críticos de controlo e limites '
    'críticos), que deve ser validado pelo responsável. Os registos devem ser conservados '
    'durante o prazo definido nesse plano.</p>',
  );
  b.writeln('<table class="assinaturas"><tr>'
      '<td>Elaborado por<br><br><span class="linha"></span><br>Nome e data</td>'
      '<td>Verificado pelo responsável HACCP<br><br><span class="linha"></span><br>Assinatura e data</td>'
      '</tr></table>');
  b.writeln(
    '<p class="integridade">Documento ${e(r.codigo)} · $total registos · '
    'código de integridade <b>${r.integridade}</b> · emitido em ${_dh(r.emitidoEm)}</p>',
  );
  return b.toString();
}

/// Estilo do relatório (A4, com o número do documento e as páginas no rodapé).
String haccpRelatorioEstilo(String codigo) =>
    '''
  @page { size: A4; margin: 16mm 14mm 18mm 14mm;
    @bottom-left { content: "$codigo"; font-size: 9px; color: #555; }
    @bottom-right { content: "Pág. " counter(page) " de " counter(pages); font-size: 9px; color: #555; }
  }
  body { font-size: 12px; padding: 0; }
  h1 { font-size: 17px; margin: 0; }
  h2 { font-size: 14px; margin: 18px 0 6px; padding-bottom: 3px; border-bottom: 2px solid #333; }
  h3 { font-size: 12.5px; margin: 12px 0 2px; }
  p.sub { font-size: 13px; margin: 2px 0 10px; color: #333; }
  p.meta { margin: 0 0 4px; color: #333; }
  p.vazio, p.nota { color: #555; }
  p.nota { font-size: 10.5px; margin-top: 8px; }
  p.integridade { margin-top: 14px; font-size: 10px; color: #444; border-top: 1px solid #999; padding-top: 6px; }
  table { border-collapse: collapse; width: 100%; max-width: none; margin: 4px 0 8px; page-break-inside: auto; }
  tr { page-break-inside: avoid; }
  th, td { border: 1px solid #888; padding: 4px 6px; text-align: left; vertical-align: top; font-size: 11px; }
  th { background: #eee; }
  table.ficha th { width: 18%; }
  table.resumo td { text-align: center; font-size: 11px; width: 20%; }
  table.resumo b { font-size: 16px; }
  tr.nc td, td.nc { background: #fde4e4; }
  ul.lei { margin: 4px 0 4px 18px; padding: 0; font-size: 11px; }
  table.assinaturas td { height: 70px; border: none; border-top: 1px solid #aaa; width: 50%; font-size: 11px; }
  span.linha { display: inline-block; width: 85%; border-bottom: 1px solid #000; }
''';
