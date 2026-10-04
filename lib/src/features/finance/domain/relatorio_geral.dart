import '../../daily_count/domain/contagem_dia.dart';
import '../../daily_count/domain/local.dart';
import '../../daily_count/domain/movimento_produto.dart';
import '../../ingredients/domain/ingredient.dart';
import '../../invoices/domain/fatura.dart';
import '../../sales/domain/venda.dart';
import '../../schedule/domain/production_plan.dart';
import '../../tech_sheets/domain/tech_sheet.dart';
import 'custo_fixo.dart';
import 'equipamento.dart';

/// Uma folha do relatório (uma tabela): nome, colunas e linhas de valores
/// (`String`, `num`, `bool` ou `null` = célula vazia).
class FolhaRelatorio {
  const FolhaRelatorio({
    required this.nome,
    required this.colunas,
    required this.linhas,
  });

  final String nome;
  final List<String> colunas;
  final List<List<Object?>> linhas;
}

/// Uma linha de composição de um produto (ficha técnica): massa, recheios,
/// coberturas, extras e embalagens, com a quantidade e o custo.
class ComponenteSabor {
  const ComponenteSabor({
    required this.fichaId,
    required this.componente,
    required this.item,
    required this.tipo,
    required this.quantidade,
    required this.unidade,
    required this.custoUnitario,
    required this.custoLinha,
    this.eEmbalagem = false,
  });

  final String fichaId;

  /// "Massa", "Recheio (base)", "Embalagem"…
  final String componente;
  final String item;

  /// `ingrediente`, `receita`, `embalagem` ou `kit`.
  final String tipo;
  final double quantidade;

  /// `g` ou `peças`.
  final String unidade;

  /// € por [unidade].
  final double custoUnitario;
  final double custoLinha;
  final bool eEmbalagem;
}

/// Um ingrediente "cru" de um produto, por unidade (já desdobrado através das
/// massas e recheios) — `GET /fichas/{id}/plano?unidades=1`.
class IngredienteDoSabor {
  const IngredienteDoSabor({
    required this.fichaId,
    required this.ingredienteId,
    required this.nome,
    required this.quantidade,
    required this.unidade,
  });

  final String fichaId;
  final String ingredienteId;
  final String nome;
  final double quantidade;
  final String unidade;
}

/// Tudo o que o Relatório geral usa — carregado pelo serviço e transformado
/// em folhas por [montarRelatorio] (função pura, testável).
class EntradaRelatorio {
  const EntradaRelatorio({
    required this.empresa,
    required this.desde,
    required this.ate,
    required this.geradoEm,
    this.ivaAssumidoPercent,
    this.vendas = const [],
    this.itens = const [],
    this.fichas = const [],
    this.componentes = const [],
    this.ingredientesDosSabores = const [],
    this.ingredientes = const [],
    this.custosFixos = const [],
    this.equipamentos = const [],
    this.faturas = const [],
    this.producoes = const [],
    this.itensProducao = const [],
    this.locais = const [],
    this.movimentosProduto = const [],
  });

  final String empresa;
  final DateTime desde;
  final DateTime ate;
  final DateTime geradoEm;

  /// Taxa de IVA a assumir nas linhas de venda sem IVA registado; `null` =
  /// não estimar (a coluna "sem IVA" fica vazia nessas linhas).
  final double? ivaAssumidoPercent;

  final List<Venda> vendas;
  final List<VendaItem> itens;
  final List<FichaTecnica> fichas;
  final List<ComponenteSabor> componentes;
  final List<IngredienteDoSabor> ingredientesDosSabores;
  final List<Ingrediente> ingredientes;
  final List<CustoFixo> custosFixos;
  final List<Equipamento> equipamentos;
  final List<Fatura> faturas;
  final List<ProducaoPlan> producoes;

  /// Linhas de produção, com [ItemProducaoRelatorio.producaoId] para ligar ao plano.
  final List<ItemProducaoRelatorio> itensProducao;

  /// Locais (loja, Alvalade, plataformas) e o registo diário de cookies
  /// (assados, envios, desperdício, contagens) — inclui alguns dias antes do
  /// período para a abertura herdar o último fecho.
  final List<Local> locais;
  final List<MovimentoProduto> movimentosProduto;
}

/// Linha de produção + o plano a que pertence (o modelo da agenda não guarda
/// o id do plano na linha).
class ItemProducaoRelatorio {
  const ItemProducaoRelatorio({required this.producaoId, required this.item});
  final String producaoId;
  final ProducaoItem item;
}

// ---------------------------------------------------------------------------
// utilitários
// ---------------------------------------------------------------------------

double _r2(double v) => (v * 100).roundToDouble() / 100;
double _r4(double v) => (v * 10000).roundToDouble() / 10000;

String _ymd(DateTime d) => ymd(d);
String _mes(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

DateTime _dia(DateTime d) => DateTime(d.year, d.month, d.day);

/// Os meses (primeiro dia) entre [desde] e [ate], inclusive.
List<DateTime> mesesDoPeriodo(DateTime desde, DateTime ate) {
  final out = <DateTime>[];
  var m = DateTime(desde.year, desde.month, 1);
  while (!m.isAfter(ate)) {
    out.add(m);
    m = DateTime(m.year, m.month + 1, 1);
  }
  return out;
}

String _semAcentos(String s) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const para = 'aaaaaeeeeiiiiooooouuuucn';
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    final i = de.indexOf(c);
    b.write(i >= 0 ? para[i] : c);
  }
  return b.toString();
}

/// Categoria de despesa (da lista da especificação) a partir do nome de um
/// custo fixo/variável registado — por palavras-chave. Em dúvida: "outras".
String categoriaDeCusto(String nome) {
  final n = _semAcentos(nome);
  bool tem(List<String> ps) => ps.any(n.contains);
  if (tem(['renda', 'aluguel', 'aluguer', 'arrend'])) return 'renda';
  if (tem(['eletric', 'luz', 'agua', 'gas ', 'energia', 'edp', 'epal'])) {
    return 'eletricidade e água';
  }
  if (tem(['internet', 'telefon', 'telemov', 'fibra', 'vodafone', 'meo'])) {
    return 'internet e telefone';
  }
  if (tem(['contab', 'toc'])) return 'contabilidade';
  if (tem(['segur'])) return 'seguros';
  if (tem([
    'market',
    'anunc',
    'publicid',
    'influenc',
    'instagram',
    'facebook',
    'meta ',
    'google ads',
    'video',
    'freelanc',
  ])) {
    return 'marketing';
  }
  if (tem([
    'software',
    'subscri',
    'netflix',
    'spotify',
    'vendus',
    'dropbox',
    'canva',
    'app ',
  ])) {
    return 'software e subscrições';
  }
  if (tem([
    'salario',
    'pessoal',
    'ordenado',
    'funcionar',
    'staff',
    'seguranca social',
    'tsu',
  ])) {
    return 'pessoal';
  }
  if (tem(['imposto', 'irc', 'irs', 'derrama', 'taxa'])) return 'impostos';
  if (tem(['equipament', 'forno', 'manuten'])) return 'equipamento';
  if (tem(['embalag'])) return 'embalagem';
  if (tem(['ingredient', 'materia'])) return 'ingredientes';
  return 'outras';
}

DateTime? _dataFatura(Fatura f) {
  final s = f.dataFatura.length >= 10 ? f.dataFatura.substring(0, 10) : '';
  final d = DateTime.tryParse(s);
  if (d != null) return d;
  final c = f.created.length >= 10 ? f.created.substring(0, 10) : '';
  return DateTime.tryParse(c);
}

bool _noPeriodo(DateTime? d, DateTime desde, DateTime ate) =>
    d != null && !_dia(d).isBefore(_dia(desde)) && !_dia(d).isAfter(_dia(ate));

/// Faturas que contam para o relatório: confirmadas, não apagadas, no período.
List<Fatura> _faturasValidas(EntradaRelatorio e) => [
  for (final f in e.faturas)
    if (!f.apagada &&
        f.estado == FaturaEstado.confirmada &&
        _noPeriodo(_dataFatura(f), e.desde, e.ate))
      f,
];

class _LinhaDespesa {
  _LinhaDespesa({
    required this.data,
    required this.categoria,
    required this.fornecedor,
    required this.descricao,
    required this.comIva,
    required this.semIva,
    required this.tipo,
    required this.fonte,
    this.documento = '',
    this.compraMateriaPrima = false,
    this.depreciacao = false,
  });

  final DateTime data;
  final String categoria;
  final String fornecedor;
  final String descricao;
  final double comIva;
  final double? semIva;
  final String tipo; // fixa | variavel
  final String fonte;
  final String documento;

  /// Compra de ingredientes/embalagem (já contada no custo dos produtos
  /// vendidos — não entra duas vezes no resultado).
  final bool compraMateriaPrima;
  final bool depreciacao;
}

List<_LinhaDespesa> _despesas(EntradaRelatorio e) {
  final out = <_LinhaDespesa>[];

  // 1) Faturas de compra, repartidas por categoria conforme as linhas lidas.
  for (final f in _faturasValidas(e)) {
    if (f.tipo != FaturaTipo.fatura) continue;
    final data = _dataFatura(f)!;
    final linhas = f.linhasIa;
    final porCat = <String, double>{};
    for (final l in linhas) {
      final cat = l.embalagem
          ? 'embalagem'
          : l.consumivel
          ? 'outras'
          : 'ingredientes';
      porCat[cat] = (porCat[cat] ?? 0) + (l.total ?? 0);
    }
    final soma = porCat.values.fold<double>(0, (s, v) => s + v);
    final totalCom = f.total;
    final totalSem = f.iva > 0 && f.total >= f.iva ? f.total - f.iva : null;
    if (soma <= 0) {
      out.add(
        _LinhaDespesa(
          data: data,
          categoria: 'outras',
          fornecedor: f.fornecedor,
          descricao: 'Fatura sem linhas lidas',
          comIva: _r2(totalCom),
          semIva: totalSem == null ? null : _r2(totalSem),
          tipo: 'variavel',
          fonte: 'fatura',
          documento: f.numero,
        ),
      );
      continue;
    }
    for (final entry in porCat.entries) {
      final quota = entry.value / soma;
      out.add(
        _LinhaDespesa(
          data: data,
          categoria: entry.key,
          fornecedor: f.fornecedor,
          descricao: 'Fatura ${f.numero}'.trim(),
          comIva: _r2(totalCom * quota),
          semIva: totalSem == null ? null : _r2(totalSem * quota),
          tipo: 'variavel',
          fonte: 'fatura',
          documento: f.numero,
          compraMateriaPrima:
              entry.key == 'ingredientes' || entry.key == 'embalagem',
        ),
      );
    }
  }

  // 2) Custos fixos/variáveis registados: o valor atual aplicado a cada mês.
  for (final m in mesesDoPeriodo(e.desde, e.ate)) {
    for (final c in e.custosFixos) {
      if (!c.ativo) continue;
      final dia = c.diaPagamento == null
          ? 1
          : c.diaPagamento!.clamp(1, DateTime(m.year, m.month + 1, 0).day);
      out.add(
        _LinhaDespesa(
          data: DateTime(m.year, m.month, dia),
          categoria: categoriaDeCusto(c.nome),
          fornecedor: '',
          descricao: c.nome,
          comIva: _r2(c.valorMensal),
          semIva: null,
          tipo: c.tipo == TipoCusto.fixo ? 'fixa' : 'variavel',
          fonte: 'custo mensal registado',
        ),
      );
    }
    // 3) Depreciação dos equipamentos (custo diluído; não é saída de caixa).
    for (final q in e.equipamentos) {
      if (!q.ativo || q.custoMensal <= 0) continue;
      out.add(
        _LinhaDespesa(
          data: DateTime(m.year, m.month, 1),
          categoria: 'equipamento',
          fornecedor: '',
          descricao: '${q.nome} (depreciação)',
          comIva: _r2(q.custoMensal),
          semIva: null,
          tipo: 'fixa',
          fonte: 'depreciação',
          depreciacao: true,
        ),
      );
    }
  }
  out.sort((a, b) => a.data.compareTo(b.data));
  return out;
}

// ---------------------------------------------------------------------------
// folhas
// ---------------------------------------------------------------------------

/// Valor sem IVA de uma linha de venda e de onde veio.
({double? valor, double? iva, String origem}) _semIva(
  VendaItem it,
  double? ivaAssumido,
) {
  if (it.valorSemIva != null) {
    return (
      valor: _r2(it.valorSemIva!),
      iva: it.ivaPercent,
      origem: 'registado',
    );
  }
  if (ivaAssumido != null) {
    return (
      valor: _r2(it.totalLinha / (1 + ivaAssumido / 100)),
      iva: ivaAssumido,
      origem:
          'estimado (${ivaAssumido.toStringAsFixed(ivaAssumido == ivaAssumido.roundToDouble() ? 0 : 1)} %)',
    );
  }
  return (valor: null, iva: null, origem: 'desconhecido');
}

/// Monta todas as folhas do relatório (ver `especificacao-relatorios.md`).
List<FolhaRelatorio> montarRelatorio(EntradaRelatorio e) {
  final fichaPorId = {for (final f in e.fichas) f.id: f};
  final vendaPorId = {for (final v in e.vendas) v.id: v};
  final ingPorId = {for (final i in e.ingredientes) i.id: i};

  // --- 1 Vendas -------------------------------------------------------------
  final linhasVenda = <List<Object?>>[];
  final itensNoPeriodo = <(Venda, VendaItem)>[];
  for (final it in e.itens) {
    final v = vendaPorId[it.vendaId];
    if (v == null || !_noPeriodo(v.data, e.desde, e.ate)) continue;
    itensNoPeriodo.add((v, it));
  }
  itensNoPeriodo.sort((a, b) {
    final c = a.$1.data.compareTo(b.$1.data);
    return c != 0 ? c : a.$1.hora.compareTo(b.$1.hora);
  });
  for (final (v, it) in itensNoPeriodo) {
    final ficha = it.fichaId == null ? null : fichaPorId[it.fichaId];
    final s = _semIva(it, e.ivaAssumidoPercent);
    linhasVenda.add([
      _ymd(v.data),
      v.hora.isEmpty ? null : v.hora,
      v.canal.isEmpty ? 'Não indicado' : v.canal,
      ficha?.nome ?? '(produto não identificado)',
      it.quantidade,
      _r2(it.precoUnitario),
      it.desconto,
      s.valor,
      s.iva,
      s.origem,
      _r2(it.totalLinha),
      null, // comissão do canal: ainda não é registada
      v.metodoPagamento.isEmpty ? null : v.metodoPagamento,
      null, // tipo de cliente: ainda não é registado
      it.custoUnitarioSnapshot > 0 ? _r4(it.custoUnitarioSnapshot) : null,
      v.numeroDocumento.isEmpty ? null : v.numeroDocumento,
      v.origem.label,
      it.descricao,
    ]);
  }
  final folhaVendas = FolhaRelatorio(
    nome: '1 Vendas',
    colunas: const [
      'data',
      'hora',
      'canal',
      'sabor',
      'quantidade',
      'preco_unitario_com_iva',
      'desconto',
      'valor_liquido_sem_iva',
      'iva_percent',
      'iva_origem',
      'valor_com_iva',
      'comissao_canal',
      'metodo_pagamento',
      'tipo_cliente',
      'custo_materia_prima_unitario',
      'documento',
      'origem_registo',
      'descricao_original',
    ],
    linhas: linhasVenda,
  );

  // Tabela de equivalência: como cada produto aparece nas vendas (nomes antigos,
  // abreviaturas do POS) e a que sabor oficial corresponde.
  final equiv = <String, ({String sabor, double unidades, int linhas})>{};
  for (final (_, it) in itensNoPeriodo) {
    final ficha = it.fichaId == null ? null : fichaPorId[it.fichaId];
    final chave = '${it.descricao.trim()}|${ficha?.nome ?? ''}';
    final atual = equiv[chave];
    equiv[chave] = (
      sabor: ficha?.nome ?? '(produto não identificado)',
      unidades: (atual?.unidades ?? 0) + it.quantidade,
      linhas: (atual?.linhas ?? 0) + 1,
    );
  }
  final equivOrdenada = equiv.entries.toList()
    ..sort((a, b) => b.value.unidades.compareTo(a.value.unidades));
  final folhaEquivalencia = FolhaRelatorio(
    nome: '1 Equivalencia nomes',
    colunas: const [
      'descricao_na_venda',
      'sabor_oficial',
      'linhas',
      'unidades',
    ],
    linhas: [
      for (final e in equivOrdenada)
        [
          e.key.substring(0, e.key.lastIndexOf('|')),
          e.value.sabor,
          e.value.linhas,
          e.value.unidades,
        ],
    ],
  );

  // --- despesas -------------------------------------------------------------
  final despesas = _despesas(e);
  final folhaDespesas = FolhaRelatorio(
    nome: '4 Despesas',
    colunas: const [
      'data',
      'categoria',
      'fornecedor',
      'descricao',
      'valor_com_iva',
      'valor_sem_iva',
      'tipo',
      'fonte',
      'documento',
    ],
    linhas: [
      for (final d in despesas)
        [
          _ymd(d.data),
          d.categoria,
          d.fornecedor.isEmpty ? null : d.fornecedor,
          d.descricao,
          d.comIva,
          d.semIva,
          d.tipo,
          d.fonte,
          d.documento.isEmpty ? null : d.documento,
        ],
    ],
  );

  // --- resumo mensal + tesouraria ------------------------------------------
  final meses = mesesDoPeriodo(e.desde, e.ate);
  final resumo = <List<Object?>>[];
  final tesouraria = <List<Object?>>[];
  for (final m in meses) {
    final chave = _mes(m);
    final doMes = [
      for (final (v, it) in itensNoPeriodo)
        if (_mes(v.data) == chave) (v, it),
    ];
    final docs = {for (final (v, _) in doMes) v.id}.length;
    final unidades = doMes.fold<double>(0, (s, p) => s + p.$2.quantidade);
    final comIva = doMes.fold<double>(0, (s, p) => s + p.$2.totalLinha);
    var semIva = 0.0;
    var semIvaCompleto = true;
    for (final (_, it) in doMes) {
      final s = _semIva(it, e.ivaAssumidoPercent);
      if (s.valor == null) {
        semIvaCompleto = false;
      } else {
        semIva += s.valor!;
      }
    }
    final cmv = doMes.fold<double>(
      0,
      (s, p) => s + p.$2.custoUnitarioSnapshot * p.$2.quantidade,
    );
    final desp = [
      for (final d in despesas)
        if (_mes(d.data) == chave) d,
    ];
    double soma(bool Function(_LinhaDespesa) f) =>
        desp.where(f).fold<double>(0, (s, d) => s + (d.semIva ?? d.comIva));
    final compras = soma((d) => d.compraMateriaPrima);
    final fixas = soma(
      (d) => !d.compraMateriaPrima && !d.depreciacao && d.tipo == 'fixa',
    );
    final variaveis = soma(
      (d) => !d.compraMateriaPrima && d.tipo == 'variavel',
    );
    final deprec = soma((d) => d.depreciacao);
    final margemBruta = semIvaCompleto ? semIva - cmv : null;
    final resultado = margemBruta == null
        ? null
        : margemBruta - fixas - variaveis - deprec;
    // IVA: cobrado nas vendas (registado ou estimado) e pago nas compras
    var ivaLiq = 0.0;
    var ivaDesconhecido = false;
    for (final (_, it) in doMes) {
      final s = _semIva(it, e.ivaAssumidoPercent);
      if (s.valor == null) {
        ivaDesconhecido = true;
      } else {
        ivaLiq += it.totalLinha - s.valor!;
      }
    }
    final ivaCompras = desp
        .where((d) => d.fonte == 'fatura' && d.semIva != null)
        .fold<double>(0, (s, d) => s + d.comIva - d.semIva!);
    resumo.add([
      chave,
      docs,
      unidades,
      _r2(comIva),
      semIvaCompleto ? _r2(semIva) : null,
      _r2(cmv),
      margemBruta == null ? null : _r2(margemBruta),
      _r2(fixas),
      _r2(variaveis),
      _r2(deprec),
      _r2(compras),
      resultado == null ? null : _r2(resultado),
      ivaDesconhecido ? null : _r2(ivaLiq),
      _r2(ivaCompras),
      ivaDesconhecido ? null : _r2(ivaLiq - ivaCompras),
    ]);

    final saidasFaturas = desp
        .where((d) => d.fonte == 'fatura')
        .fold<double>(0, (s, d) => s + d.comIva);
    final saidasCustos = desp
        .where((d) => d.fonte == 'custo mensal registado')
        .fold<double>(0, (s, d) => s + d.comIva);
    tesouraria.add([
      chave,
      _r2(comIva),
      _r2(saidasFaturas),
      _r2(saidasCustos),
      _r2(saidasFaturas + saidasCustos),
      _r2(comIva - saidasFaturas - saidasCustos),
      null,
      null,
    ]);
  }
  final folhaResumo = FolhaRelatorio(
    nome: 'Resumo mensal',
    colunas: const [
      'mes',
      'n_vendas',
      'unidades_vendidas',
      'vendas_com_iva',
      'vendas_sem_iva',
      'custo_materia_prima_vendida',
      'margem_bruta_sem_iva',
      'despesas_fixas',
      'despesas_variaveis',
      'depreciacao_equipamentos',
      'compras_ingredientes_e_embalagem',
      'resultado_estimado',
      'iva_cobrado_nas_vendas',
      'iva_das_compras',
      'iva_a_entregar',
    ],
    linhas: resumo,
  );
  final folhaTesouraria = FolhaRelatorio(
    nome: '7 Tesouraria',
    colunas: const [
      'mes',
      'entradas_vendas_com_iva',
      'saidas_faturas_com_iva',
      'saidas_custos_registados',
      'saidas_total',
      'saldo_do_mes',
      'saldo_fim_de_mes',
      'dividas_e_prestacoes',
    ],
    linhas: tesouraria,
  );

  // --- 3 Custo por sabor ----------------------------------------------------
  final fichasAtivas = [
    for (final f in e.fichas)
      if (!f.deletado) f,
  ]..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
  final custoSabor = <List<Object?>>[];
  for (final f in fichasAtivas) {
    final comps = e.componentes.where((c) => c.fichaId == f.id).toList();
    final embalagem = comps
        .where((c) => c.eEmbalagem)
        .fold<double>(0, (s, c) => s + c.custoLinha);
    final precoSemIva = e.ivaAssumidoPercent != null && f.precoVenda > 0
        ? f.precoVenda / (1 + e.ivaAssumidoPercent! / 100)
        : null;
    final margemEur = precoSemIva == null ? null : precoSemIva - f.custoProduto;
    custoSabor.add([
      f.nome,
      f.subnome.isEmpty ? null : f.subnome,
      f.categoria.isEmpty ? null : f.categoria,
      f.pesoProduto > 0 ? _r2(f.pesoProduto) : null,
      _r4(f.custoProduto - embalagem),
      _r4(embalagem),
      _r4(f.custoProduto),
      f.precoVenda > 0 ? _r2(f.precoVenda) : null,
      precoSemIva == null ? null : _r2(precoSemIva),
      margemEur == null ? null : _r2(margemEur),
      margemEur == null || precoSemIva == 0
          ? null
          : _r2(margemEur / precoSemIva! * 100),
      f.custoCompleto,
      f.custoSemDados.isEmpty
          ? null
          : f.custoSemDados.map((x) => x.nome).join(', '),
      f.nomesVenda.isEmpty ? null : f.nomesVenda.join(' | '),
    ]);
  }
  final folhaCustoSabor = FolhaRelatorio(
    nome: '3 Custo por sabor',
    colunas: const [
      'sabor',
      'subnome',
      'categoria',
      'peso_unidade_g',
      'custo_ingredientes_por_unidade',
      'custo_embalagem_por_unidade',
      'custo_total_por_unidade',
      'preco_venda_com_iva',
      'preco_venda_sem_iva',
      'margem_eur_por_unidade',
      'margem_percent',
      'custo_completo',
      'ingredientes_sem_preco',
      'nomes_antigos_ou_de_venda',
    ],
    linhas: custoSabor,
  );

  final folhaComponentes = FolhaRelatorio(
    nome: '3 Componentes',
    colunas: const [
      'sabor',
      'componente',
      'item',
      'tipo',
      'quantidade_por_unidade',
      'unidade',
      'custo_por_unidade_de_medida',
      'custo_na_unidade_de_produto',
    ],
    linhas: [
      for (final f in fichasAtivas)
        for (final c in e.componentes.where((c) => c.fichaId == f.id))
          [
            f.nome,
            c.componente,
            c.item,
            c.tipo,
            _r4(c.quantidade),
            c.unidade,
            _r4(c.custoUnitario),
            _r4(c.custoLinha),
          ],
    ],
  );

  final linhasIng = <List<Object?>>[];
  for (final f in fichasAtivas) {
    final ings =
        e.ingredientesDosSabores.where((i) => i.fichaId == f.id).toList()
          ..sort((a, b) => b.quantidade.compareTo(a.quantidade));
    for (final i in ings) {
      final ing = ingPorId[i.ingredienteId];
      final cpg = ing?.custoPorGrama ?? 0;
      linhasIng.add([
        f.nome,
        i.nome,
        ing?.marca.isEmpty ?? true ? null : ing!.marca,
        ing?.fornecedor.isEmpty ?? true ? null : ing!.fornecedor,
        _r4(i.quantidade),
        i.unidade,
        ing == null || ing.preco <= 0 ? null : _r2(ing.preco),
        ing == null || ing.gramasEmbalagem <= 0
            ? null
            : _r2(ing.gramasEmbalagem),
        cpg > 0 ? _r4(cpg) : null,
        cpg > 0 ? _r4(cpg * i.quantidade) : null,
        ing?.precoAtualizadoEm == null ? null : _ymd(ing!.precoAtualizadoEm!),
      ]);
    }
  }
  final folhaIngredientes = FolhaRelatorio(
    nome: '3 Ingredientes',
    colunas: const [
      'sabor',
      'ingrediente',
      'marca',
      'fornecedor',
      'quantidade_por_unidade',
      'unidade',
      'preco_compra_com_embalagem',
      'embalagem_g_ou_ml',
      'custo_por_g_ou_ml',
      'custo_na_unidade_de_produto',
      'preco_atualizado_em',
    ],
    linhas: linhasIng,
  );

  // Histórico de preços de compra: linhas lidas das faturas confirmadas.
  final historico = <List<Object?>>[];
  final fats = _faturasValidas(e)
    ..sort((a, b) => _dataFatura(a)!.compareTo(_dataFatura(b)!));
  for (final f in fats) {
    for (final l in f.linhasIa) {
      historico.add([
        _ymd(_dataFatura(f)!),
        f.fornecedor.isEmpty ? null : f.fornecedor,
        f.numero.isEmpty ? null : f.numero,
        l.embalagem
            ? 'embalagem'
            : l.consumivel
            ? 'consumível'
            : 'ingrediente',
        l.nomeGenerico.isEmpty ? l.descricao : l.nomeGenerico,
        l.marca.isEmpty ? null : l.marca,
        l.descricao,
        l.quantidade,
        l.unidade.isEmpty ? null : l.unidade,
        l.precoUnitario == null ? null : _r4(l.precoUnitario!),
        l.total == null ? null : _r2(l.total!),
        l.embalagemG,
        l.embalagemUnidade,
      ]);
    }
  }
  final folhaHistorico = FolhaRelatorio(
    nome: '3 Historico precos',
    colunas: const [
      'data',
      'fornecedor',
      'documento',
      'tipo',
      'produto',
      'marca',
      'descricao_na_fatura',
      'quantidade',
      'unidade',
      'preco_unitario',
      'total_linha',
      'embalagem',
      'embalagem_unidade',
    ],
    linhas: historico,
  );

  // --- 2 Produção -------------------------------------------------------------
  final planoPorId = {for (final p in e.producoes) p.id: p};
  final vendidoPorDiaSabor = <String, double>{};
  for (final (v, it) in itensNoPeriodo) {
    if (it.fichaId == null) continue;
    final k = '${_ymd(v.data)}|${it.fichaId}';
    vendidoPorDiaSabor[k] = (vendidoPorDiaSabor[k] ?? 0) + it.quantidade;
  }
  final producao = <List<Object?>>[];
  final itensProd = [...e.itensProducao]
    ..sort((a, b) {
      final pa = planoPorId[a.producaoId];
      final pb = planoPorId[b.producaoId];
      if (pa == null || pb == null) return 0;
      return pa.data.compareTo(pb.data);
    });
  for (final ip in itensProd) {
    final p = planoPorId[ip.producaoId];
    if (p == null || p.estado == EstadoProducao.cancelada) continue;
    if (!_noPeriodo(p.data, e.desde, e.ate)) continue;
    final it = ip.item;
    final vendido = it.fichaId.isEmpty
        ? null
        : vendidoPorDiaSabor['${_ymd(p.data)}|${it.fichaId}'];
    producao.add([
      _ymd(p.data),
      it.titulo,
      it.fichaId.isEmpty
          ? 'receita (massa/recheio/cobertura)'
          : 'produto final',
      it.formatoNome.isEmpty ? null : it.formatoNome,
      it.quantidadeKg > 0 ? _r2(it.quantidadeKg) : null,
      it.unidadesPrevistas > 0 ? it.unidadesPrevistas : null,
      vendido,
      null, // sobras
      null, // desperdício e motivo
      null, // horas de trabalho
      p.estado.label,
    ]);
  }
  final folhaProducao = FolhaRelatorio(
    nome: '2 Producao',
    colunas: const [
      'data',
      'sabor',
      'tipo_de_linha',
      'formato',
      'quantidade_kg',
      'unidades_produzidas',
      'unidades_vendidas_no_dia',
      'sobras',
      'desperdicio_e_motivo',
      'horas_trabalho_producao',
      'estado_do_plano',
    ],
    linhas: producao,
  );

  // --- 2 Contagem diária (assados, sobras, desperdício por local) ----------------
  final vendasLocal = vendasPorLocal(
    vendas: e.vendas,
    itens: e.itens,
    locais: e.locais,
  );
  final nomeLocal = {for (final l in e.locais) l.id: l.nome};
  final linhasContagem = <List<Object?>>[];
  final diasComRegisto = <(DateTime, String)>{};
  for (final m in e.movimentosProduto) {
    if (!_noPeriodo(m.data, e.desde, e.ate)) continue;
    diasComRegisto.add((_dia(m.data), m.localId));
    if (m.destinoId.isNotEmpty) diasComRegisto.add((_dia(m.data), m.destinoId));
  }
  final diasOrdenados = diasComRegisto.toList()
    ..sort((a, b) {
      final c = a.$1.compareTo(b.$1);
      return c != 0
          ? c
          : (nomeLocal[a.$2] ?? '').compareTo(nomeLocal[b.$2] ?? '');
    });
  for (final (dia, localId) in diasOrdenados) {
    final linhas = calcularContagemDia(
      localId: localId,
      dia: dia,
      fichaIds: [for (final f in fichasAtivas) f.id],
      movimentos: e.movimentosProduto,
      vendas: vendasLocal,
    );
    for (final l in linhas) {
      if (!l.temMovimento) continue;
      final motivos = <String, double>{};
      for (final m in e.movimentosProduto) {
        if (m.tipo == TipoMovimento.desperdicio &&
            m.localId == localId &&
            m.fichaId == l.fichaId &&
            _dia(m.data) == dia) {
          final k = m.motivo?.label ?? 'sem motivo';
          motivos[k] = (motivos[k] ?? 0) + m.quantidade;
        }
      }
      linhasContagem.add([
        _ymd(dia),
        nomeLocal[localId] ?? '',
        fichaPorId[l.fichaId]?.nome ?? '',
        l.abertura,
        l.assados,
        l.recebido,
        l.enviado,
        l.vendido,
        l.desperdicio,
        motivos.isEmpty
            ? null
            : motivos.entries
                  .map(
                    (x) =>
                        '${x.key} ${x.value.toStringAsFixed(x.value == x.value.roundToDouble() ? 0 : 1)}',
                  )
                  .join('; '),
        l.esperado,
        l.fecho,
        l.diferenca,
      ]);
    }
  }
  final folhaContagem = FolhaRelatorio(
    nome: '2 Contagem diaria',
    colunas: const [
      'data',
      'local',
      'sabor',
      'abertura',
      'assados',
      'recebidos',
      'enviados',
      'vendidos',
      'desperdicio',
      'desperdicio_motivo',
      'devia_haver',
      'sobras_contadas',
      'diferenca_contado_menos_esperado',
    ],
    linhas: linhasContagem,
  );

  // --- modelos por preencher ---------------------------------------------------
  const folhaPlataformas = FolhaRelatorio(
    nome: '5 Plataformas',
    colunas: [
      'plataforma',
      'periodo_extrato',
      'pedidos',
      'valor_bruto',
      'comissao',
      'taxas',
      'reembolsos_e_cancelamentos',
      'avaliacao_media',
      'tempo_medio_entrega_min',
      'codigo_postal_ou_zona',
    ],
    linhas: [],
  );
  const folhaPessoal = FolhaRelatorio(
    nome: '6 Pessoal',
    colunas: ['semana_inicio', 'pessoa', 'horas', 'custo_mensal_total'],
    linhas: [],
  );
  const folhaEventos = FolhaRelatorio(
    nome: '8 Eventos',
    colunas: ['data_inicio', 'data_fim', 'tipo', 'descricao', 'valor_eur'],
    linhas: [],
  );
  const folhaOrigem = FolhaRelatorio(
    nome: '9 Origem clientes',
    colunas: [
      'mes',
      'instagram',
      'passou_a_porta',
      'amigo',
      'plataforma',
      'outro',
    ],
    linhas: [],
  );

  // --- Leia-me -----------------------------------------------------------------
  final comCanal = itensNoPeriodo.where((p) => p.$1.canal.isNotEmpty).length;
  final comHora = itensNoPeriodo.where((p) => p.$1.hora.isNotEmpty).length;
  final comSemIva = itensNoPeriodo
      .where((p) => p.$2.valorSemIva != null)
      .length;
  final semProduto = itensNoPeriodo.where((p) => p.$2.fichaId == null).length;
  String pct(int n, int total) =>
      total == 0 ? 'sem linhas' : '${(n / total * 100).round()} % das linhas';

  final leiame = FolhaRelatorio(
    nome: 'Leia-me',
    colunas: const ['item', 'valor'],
    linhas: [
      ['Empresa', e.empresa],
      ['Gerado em', _ymd(e.geradoEm)],
      ['Período', '${_ymd(e.desde)} a ${_ymd(e.ate)}'],
      [
        'IVA assumido (linhas sem IVA registado)',
        e.ivaAssumidoPercent == null
            ? 'nenhum — "sem IVA" fica vazio quando não está registado'
            : '${e.ivaAssumidoPercent} %',
      ],
      [
        'Formato',
        'datas AAAA-MM-DD; valores em euros com ponto decimal; margens sem IVA',
      ],
      [null, null],
      ['RELATÓRIO', 'ESTADO / NOTAS'],
      [
        '1 Vendas',
        'Incluído. Canal indicado em ${pct(comCanal, itensNoPeriodo.length)}, '
            'hora em ${pct(comHora, itensNoPeriodo.length)}, valor sem IVA '
            'registado em ${pct(comSemIva, itensNoPeriodo.length)}; '
            '$semProduto linha(s) sem produto identificado. Comissão do canal e '
            'tipo de cliente ainda não são registados na app.'
            '${comCanal < itensNoPeriodo.length ? ' Para preencher canal, hora e valor sem IVA das vendas antigas do Vendus: Vendas → reimportar histórico do Vendus (completa as já importadas); as outras vendas podem ter o canal definido na própria venda.' : ''}',
      ],
      [
        '1 Equivalencia nomes',
        'Tabela de equivalência: a descrição de cada venda (nomes antigos, '
            'abreviaturas do POS) e o sabor oficial a que corresponde.',
      ],
      [
        '2 Producao',
        'Agenda de produção: data, sabor e quantidade planeada, e unidades '
            'vendidas no dia. As horas de trabalho ainda não são registadas.',
      ],
      [
        '2 Contagem diaria',
        e.movimentosProduto.isEmpty
            ? 'Sem registos: usa a página Contagem diária (assados, '
                  'envios a Alvalade, desperdício, contagens de abertura e '
                  'fecho) e esta folha enche-se sozinha.'
            : 'Por dia, local e sabor: abertura, assados, recebidos, '
                  'enviados, vendidos (das vendas, pelo canal), desperdício '
                  '(com motivo), o que devia haver, a sobra contada e a diferença.',
      ],
      [
        '3 Custo por sabor',
        'Incluído: custo por unidade (ingredientes e embalagem) e margem; '
            '"3 Componentes" e "3 Ingredientes" detalham a composição; '
            '"3 Historico precos" vem das faturas confirmadas. As quantidades '
            'são por unidade de produto (não por lote).',
      ],
      [
        '4 Despesas',
        'Incluído: faturas confirmadas (por categoria) + custos fixos/variáveis '
            'registados (o valor atual repetido em cada mês) + depreciação dos '
            'equipamentos. A categoria dos custos registados é deduzida do nome; '
            'valor sem IVA só existe nas faturas.',
      ],
      [
        '5 Plataformas',
        'Por preencher — a app ainda não importa extratos de plataformas.',
      ],
      ['6 Pessoal', 'Por preencher — a app ainda não regista horas.'],
      [
        '7 Tesouraria',
        'Parcial: entradas (vendas) e saídas (faturas e custos registados) por '
            'mês. O saldo em banco e as dívidas/prestações não são registados.',
      ],
      ['8 Eventos', 'Por preencher (folha manual).'],
      ['9 Origem clientes', 'Por preencher (folha manual).'],
      [null, null],
      [
        'Resumo mensal',
        'Conferência: vendas, custo da matéria-prima vendida, despesas e resultado estimado por mês.',
      ],
      [
        'Nota sobre o resultado',
        'O resultado usa o custo da matéria-prima VENDIDA (não as compras de '
            'ingredientes), para não contar o mesmo custo duas vezes.',
      ],
    ],
  );

  return [
    leiame,
    folhaResumo,
    folhaVendas,
    folhaEquivalencia,
    folhaProducao,
    folhaContagem,
    folhaCustoSabor,
    folhaComponentes,
    folhaIngredientes,
    folhaHistorico,
    folhaDespesas,
    folhaPlataformas,
    folhaPessoal,
    folhaTesouraria,
    folhaEventos,
    folhaOrigem,
  ];
}
