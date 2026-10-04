import 'package:pocketbase/pocketbase.dart';

import '../../../core/printing/html_escape.dart';

/// O que um controlo de segurança alimentar vigia.
enum TipoControlo {
  temperatura('temperatura', 'Temperatura'),
  limpeza('limpeza', 'Limpeza'),
  praga('praga', 'Pragas'),
  manutencao('manutencao', 'Manutenção / validades'),
  outro('outro', 'Outro');

  const TipoControlo(this.api, this.label);
  final String api;
  final String label;

  static TipoControlo fromApi(String? v) => TipoControlo.values.firstWhere(
    (t) => t.api == v,
    orElse: () => TipoControlo.outro,
  );
}

/// Um controlo periódico: temperatura do frigorífico, limpeza da bancada,
/// visita de controlo de pragas, validade do extintor…
class ControloHaccp {
  const ControloHaccp({
    required this.id,
    required this.nome,
    this.tipo = TipoControlo.outro,
    this.periodicidadeDias = 1,
    this.vezesPorDia = 1,
    this.limiteMin,
    this.limiteMax,
    this.unidade = '',
    this.local = '',
    this.instrucoes = '',
    this.ordem = 0,
    this.arquivado = false,
  });

  final String id;
  final String nome;
  final TipoControlo tipo;

  /// 1 = todos os dias, 7 = semanal, 30 = mensal, 365 = anual; 0 = ocasional.
  final int periodicidadeDias;

  /// Nos controlos diários, quantos registos por dia.
  final int vezesPorDia;
  final double? limiteMin;
  final double? limiteMax;
  final String unidade;
  final String local;
  final String instrucoes;
  final int ordem;
  final bool arquivado;

  bool get ativo => !arquivado;

  /// Só as temperaturas têm um valor a medir.
  bool get medeValor => tipo == TipoControlo.temperatura;

  int get esperadosPorDia =>
      periodicidadeDias == 1 ? (vezesPorDia < 1 ? 1 : vezesPorDia) : 1;

  String get periodicidadeTexto => switch (periodicidadeDias) {
    0 => 'Ocasional',
    1 => vezesPorDia > 1 ? '$vezesPorDia vezes por dia' : 'Todos os dias',
    7 => 'Todas as semanas',
    14 => 'De 15 em 15 dias',
    30 => 'Todos os meses',
    90 => 'Todos os trimestres',
    180 => 'De 6 em 6 meses',
    365 => 'Todos os anos',
    final d => 'De $d em $d dias',
  };

  /// Texto dos limites ("0 a 5 °C", "≤ -18 °C"…); vazio se não há.
  String get limitesTexto {
    final u = unidade.isEmpty ? '°C' : unidade;
    String n(double v) =>
        v == v.roundToDouble() ? '${v.toInt()}' : '$v'.replaceAll('.', ',');
    if (limiteMin != null && limiteMax != null) {
      return '${n(limiteMin!)} a ${n(limiteMax!)} $u';
    }
    if (limiteMax != null) return '≤ ${n(limiteMax!)} $u';
    if (limiteMin != null) return '≥ ${n(limiteMin!)} $u';
    return '';
  }

  /// Um valor medido está dentro dos limites?
  bool valorConforme(double valor) =>
      (limiteMin == null || valor >= limiteMin!) &&
      (limiteMax == null || valor <= limiteMax!);

  factory ControloHaccp.fromRecord(RecordModel r) {
    final tipo = TipoControlo.fromApi(r.getStringValue('tipo'));
    final temMin =
        tipo == TipoControlo.temperatura && r.getBoolValue('usa_limite_min');
    final temMax =
        tipo == TipoControlo.temperatura && r.getBoolValue('usa_limite_max');
    return ControloHaccp(
      id: r.id,
      nome: r.getStringValue('nome'),
      tipo: tipo,
      periodicidadeDias: r.getIntValue('periodicidade_dias'),
      vezesPorDia: r.getIntValue('vezes_por_dia'),
      limiteMin: temMin ? r.getDoubleValue('limite_min') : null,
      limiteMax: temMax ? r.getDoubleValue('limite_max') : null,
      unidade: r.getStringValue('unidade'),
      local: r.getStringValue('local'),
      instrucoes: r.getStringValue('instrucoes'),
      ordem: r.getIntValue('ordem'),
      arquivado: r.getBoolValue('arquivado'),
    );
  }
}

/// Dados de um controlo a criar/editar.
class ControloInput {
  ControloInput({
    required this.nome,
    this.tipo = TipoControlo.outro,
    this.periodicidadeDias = 1,
    this.vezesPorDia = 1,
    this.limiteMin,
    this.limiteMax,
    this.unidade = '',
    this.local = '',
    this.instrucoes = '',
    this.ordem = 0,
  });

  final String nome;
  final TipoControlo tipo;
  final int periodicidadeDias;
  final int vezesPorDia;
  final double? limiteMin;
  final double? limiteMax;
  final String unidade;
  final String local;
  final String instrucoes;
  final int ordem;

  Map<String, dynamic> toBody() => {
    'nome': nome.trim(),
    'tipo': tipo.api,
    'periodicidade_dias': periodicidadeDias,
    'vezes_por_dia': vezesPorDia,
    'usa_limite_min': tipo == TipoControlo.temperatura && limiteMin != null,
    'limite_min': tipo == TipoControlo.temperatura ? (limiteMin ?? 0) : 0,
    'usa_limite_max': tipo == TipoControlo.temperatura && limiteMax != null,
    'limite_max': tipo == TipoControlo.temperatura ? (limiteMax ?? 0) : 0,
    'unidade': unidade.trim(),
    'local': local.trim(),
    'instrucoes': instrucoes.trim(),
    'ordem': ordem,
  };
}

/// Um registo: o controlo foi feito (ou houve uma ocorrência).
class RegistoHaccp {
  const RegistoHaccp({
    required this.id,
    required this.controloId,
    required this.dataHora,
    this.valor,
    this.conforme = true,
    this.responsavel = '',
    this.notas = '',
    this.acaoCorretiva = '',
    this.resolvido = false,
    this.proximoVencimento,
  });

  final String id;
  final String controloId;

  /// Hora local.
  final DateTime dataHora;
  final double? valor;
  final bool conforme;
  final String responsavel;
  final String notas;
  final String acaoCorretiva;
  final bool resolvido;
  final DateTime? proximoVencimento;

  /// Uma não conformidade ainda por tratar.
  bool get abertaNaoConformidade => !conforme && !resolvido;

  DateTime get dia => DateTime(dataHora.year, dataHora.month, dataHora.day);

  factory RegistoHaccp.fromRecord(RecordModel r) {
    DateTime? d(String f) {
      final s = r.getStringValue(f);
      return s.isEmpty ? null : DateTime.tryParse(s);
    }

    final prox = d('proximo_vencimento');
    return RegistoHaccp(
      id: r.id,
      controloId: r.getStringValue('controlo'),
      dataHora: (d('data_hora') ?? DateTime.now()).toLocal(),
      // só tem sentido nos controlos de temperatura (os outros ignoram-no)
      valor: r.getDoubleValue('valor'),
      conforme: r.getBoolValue('conforme'),
      responsavel: r.getStringValue('responsavel'),
      notas: r.getStringValue('notas'),
      acaoCorretiva: r.getStringValue('acao_corretiva'),
      resolvido: r.getBoolValue('resolvido'),
      // só o dia interessa (vem em UTC à meia-noite)
      proximoVencimento: prox == null
          ? null
          : DateTime(prox.year, prox.month, prox.day),
    );
  }
}

// ---------------------------------------------------------------------------
// estado dos controlos (lembretes)
// ---------------------------------------------------------------------------

enum EstadoControlo {
  /// Feito e dentro do prazo.
  emDia,

  /// Hoje há registo(s) por fazer (ou vence hoje).
  pendenteHoje,

  /// Passou o prazo sem registo.
  atrasado,

  /// Nunca foi registado.
  semRegisto,

  /// Sem periodicidade (só quando for preciso).
  ocasional,
}

class StatusControlo {
  const StatusControlo({
    required this.controlo,
    required this.estado,
    this.ultimo,
    this.proximo,
    this.feitosHoje = 0,
    this.esperadosHoje = 1,
    this.diasAtraso = 0,
  });

  final ControloHaccp controlo;
  final EstadoControlo estado;
  final RegistoHaccp? ultimo;

  /// Quando vence a seguir (`null` = ocasional).
  final DateTime? proximo;
  final int feitosHoje;
  final int esperadosHoje;
  final int diasAtraso;

  /// Pede atenção (atrasado ou nunca registado).
  bool get emAtraso =>
      estado == EstadoControlo.atrasado || estado == EstadoControlo.semRegisto;

  bool get precisaAcaoHoje => emAtraso || estado == EstadoControlo.pendenteHoje;
}

DateTime _dia(DateTime d) => DateTime(d.year, d.month, d.day);

/// O estado de um [controlo] face aos seus [registos] (de qualquer data) em
/// [agora].
StatusControlo estadoDoControlo(
  ControloHaccp controlo,
  List<RegistoHaccp> registos,
  DateTime agora,
) {
  final hoje = _dia(agora);
  final meus = [
    for (final r in registos)
      if (r.controloId == controlo.id) r,
  ]..sort((a, b) => b.dataHora.compareTo(a.dataHora));
  final feitosHoje = meus.where((r) => r.dia == hoje).length;
  final esperados = controlo.esperadosPorDia;

  if (meus.isEmpty) {
    return StatusControlo(
      controlo: controlo,
      estado: controlo.periodicidadeDias == 0
          ? EstadoControlo.ocasional
          : EstadoControlo.semRegisto,
      esperadosHoje: esperados,
    );
  }
  final ultimo = meus.first;

  // diário: o prazo é hoje; atrasa se passou um dia inteiro sem registo
  if (controlo.periodicidadeDias == 1) {
    if (feitosHoje >= esperados) {
      return StatusControlo(
        controlo: controlo,
        estado: EstadoControlo.emDia,
        ultimo: ultimo,
        proximo: DateTime(hoje.year, hoje.month, hoje.day + 1),
        feitosHoje: feitosHoje,
        esperadosHoje: esperados,
      );
    }
    final dias = hoje.difference(ultimo.dia).inDays - 1;
    return StatusControlo(
      controlo: controlo,
      estado: dias > 0 ? EstadoControlo.atrasado : EstadoControlo.pendenteHoje,
      ultimo: ultimo,
      proximo: hoje,
      feitosHoje: feitosHoje,
      esperadosHoje: esperados,
      diasAtraso: dias > 0 ? dias : 0,
    );
  }

  // validade marcada no último registo (extintor, desinfestação…) ou
  // periodicidade a contar do último registo
  DateTime? proximo = ultimo.proximoVencimento;
  if (proximo == null && controlo.periodicidadeDias > 0) {
    proximo = DateTime(
      ultimo.dia.year,
      ultimo.dia.month,
      ultimo.dia.day + controlo.periodicidadeDias,
    );
  }
  if (proximo == null) {
    return StatusControlo(
      controlo: controlo,
      estado: EstadoControlo.ocasional,
      ultimo: ultimo,
      feitosHoje: feitosHoje,
      esperadosHoje: esperados,
    );
  }
  final EstadoControlo estado;
  var atraso = 0;
  if (hoje.isBefore(proximo)) {
    estado = EstadoControlo.emDia;
  } else if (hoje == proximo) {
    estado = EstadoControlo.pendenteHoje;
  } else {
    estado = EstadoControlo.atrasado;
    atraso = hoje.difference(proximo).inDays;
  }
  return StatusControlo(
    controlo: controlo,
    estado: estado,
    ultimo: ultimo,
    proximo: proximo,
    feitosHoje: feitosHoje,
    esperadosHoje: esperados,
    diasAtraso: atraso,
  );
}

/// O estado de cada controlo ativo, os que pedem ação primeiro.
List<StatusControlo> estadoDosControlos(
  List<ControloHaccp> controlos,
  List<RegistoHaccp> registos,
  DateTime agora,
) {
  int peso(EstadoControlo e) => switch (e) {
    EstadoControlo.atrasado => 0,
    EstadoControlo.semRegisto => 1,
    EstadoControlo.pendenteHoje => 2,
    EstadoControlo.emDia => 3,
    EstadoControlo.ocasional => 4,
  };
  final out =
      [
        for (final c in controlos)
          if (c.ativo) estadoDoControlo(c, registos, agora),
      ]..sort((a, b) {
        final p = peso(a.estado).compareTo(peso(b.estado));
        return p != 0 ? p : a.controlo.ordem.compareTo(b.controlo.ordem);
      });
  return out;
}

/// Não conformidades por tratar, das mais recentes para as mais antigas.
List<RegistoHaccp> naoConformidadesAbertas(List<RegistoHaccp> registos) => [
  for (final r in registos)
    if (r.abertaNaoConformidade) r,
]..sort((a, b) => b.dataHora.compareTo(a.dataHora));

// ---------------------------------------------------------------------------
// controlos habituais (para começar)
// ---------------------------------------------------------------------------

/// Controlos habituais numa pastelaria/loja de cookies, para não começar do
/// zero. A pessoa ajusta ou apaga o que não precisa.
List<ControloInput> controlosHabituais() => [
  ControloInput(
    nome: 'Temperatura do frigorífico',
    tipo: TipoControlo.temperatura,
    periodicidadeDias: 1,
    vezesPorDia: 2,
    limiteMin: 0,
    limiteMax: 5,
    unidade: '°C',
    local: 'Cozinha',
    instrucoes:
        'Medir de manhã e ao fim do dia. Fora de 0–5 °C: avisar e '
        'verificar os produtos.',
    ordem: 1,
  ),
  ControloInput(
    nome: 'Temperatura da arca congeladora',
    tipo: TipoControlo.temperatura,
    periodicidadeDias: 1,
    vezesPorDia: 1,
    limiteMax: -18,
    unidade: '°C',
    local: 'Cozinha',
    instrucoes: 'Deve estar a -18 °C ou menos.',
    ordem: 2,
  ),
  ControloInput(
    nome: 'Limpeza e desinfeção das bancadas e utensílios',
    tipo: TipoControlo.limpeza,
    periodicidadeDias: 1,
    ordem: 3,
    instrucoes: 'No fim de cada dia de produção.',
  ),
  ControloInput(
    nome: 'Limpeza dos equipamentos (forno, batedeira, frigoríficos)',
    tipo: TipoControlo.limpeza,
    periodicidadeDias: 7,
    ordem: 4,
  ),
  ControloInput(
    nome: 'Limpeza geral das instalações (chão, paredes, lixo)',
    tipo: TipoControlo.limpeza,
    periodicidadeDias: 1,
    ordem: 5,
  ),
  ControloInput(
    nome: 'Inspeção de armadilhas e sinais de pragas',
    tipo: TipoControlo.praga,
    periodicidadeDias: 7,
    ordem: 6,
    instrucoes: 'Registar qualquer ocorrência (excrementos, insetos, roídos).',
  ),
  ControloInput(
    nome: 'Visita da empresa de controlo de pragas',
    tipo: TipoControlo.manutencao,
    periodicidadeDias: 30,
    ordem: 7,
    instrucoes: 'Guardar o relatório da visita. Indicar a próxima visita.',
  ),
  ControloInput(
    nome: 'Extintor: inspeção e validade',
    tipo: TipoControlo.manutencao,
    periodicidadeDias: 365,
    ordem: 8,
    instrucoes: 'Indicar a data da próxima revisão.',
  ),
  ControloInput(
    nome: 'Registo de lote',
    tipo: TipoControlo.outro,
    periodicidadeDias: 0,
    ordem: 9,
    instrucoes:
        'Escrever o número do lote (receção de matérias-primas ou produção).',
  ),
];

// ---------------------------------------------------------------------------
// relatório para imprimir / guardar em PDF
// ---------------------------------------------------------------------------

String _dmy(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
String _hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _n(double v) =>
    (v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1)).replaceAll(
      '.',
      ',',
    );

/// HTML do registo HACCP de um período, por controlo, para imprimir ou
/// guardar como PDF (auditoria).
String haccpRelatorioHtml({
  required String empresa,
  required String periodo,
  required List<ControloHaccp> controlos,
  required List<RegistoHaccp> registos,
}) {
  final b = StringBuffer();
  final nc = naoConformidadesAbertas(registos);
  b.writeln('<h1>Registos de segurança alimentar (HACCP)</h1>');
  b.writeln(
    '<p class="sub">${escaparHtml(empresa)} · $periodo · '
    '${registos.length} registo(s)</p>',
  );
  if (nc.isNotEmpty) {
    b.writeln(
      '<p class="aviso"><b>${nc.length} não conformidade(s) por '
      'resolver.</b></p>',
    );
  }
  for (final c in controlos) {
    final meus = [
      for (final r in registos)
        if (r.controloId == c.id) r,
    ]..sort((a, b) => a.dataHora.compareTo(b.dataHora));
    if (meus.isEmpty) continue;
    b.writeln(
      '<h2>${escaparHtml(c.nome)}</h2>'
      '<p class="sub">${escaparHtml(c.tipo.label)} · ${escaparHtml(c.periodicidadeTexto)}'
      '${c.limitesTexto.isEmpty ? '' : ' · limites ${escaparHtml(c.limitesTexto)}'}'
      '${c.local.isEmpty ? '' : ' · ${escaparHtml(c.local)}'}</p>',
    );
    b.writeln(
      '<table><tr><th>Data</th><th>Hora</th>'
      '${c.medeValor ? '<th>Valor</th>' : ''}'
      '<th>Conforme</th><th>Quem</th><th>Notas / ação corretiva</th></tr>',
    );
    for (final r in meus) {
      final notas = [
        if (r.notas.isNotEmpty) r.notas,
        if (r.acaoCorretiva.isNotEmpty) 'Ação: ${r.acaoCorretiva}',
        if (r.proximoVencimento != null)
          'Próximo: ${_dmy(r.proximoVencimento!)}',
        if (!r.conforme) r.resolvido ? '(resolvido)' : '(por resolver)',
      ].join(' · ');
      b.writeln(
        '<tr${r.conforme ? '' : ' class="nc"'}>'
        '<td>${_dmy(r.dataHora)}</td><td>${_hm(r.dataHora)}</td>'
        '${c.medeValor ? '<td>${r.valor == null ? '' : '${_n(r.valor!)} ${escaparHtml(c.unidade.isEmpty ? '°C' : c.unidade)}'}</td>' : ''}'
        '<td>${r.conforme ? 'Sim' : 'Não'}</td>'
        '<td>${escaparHtml(r.responsavel)}</td><td>${escaparHtml(notas)}</td></tr>',
      );
    }
    b.writeln('</table>');
  }
  if (registos.isEmpty) b.writeln('<p>Sem registos neste período.</p>');
  return b.toString();
}
