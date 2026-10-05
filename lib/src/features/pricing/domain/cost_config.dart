import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'cost_config.freezed.dart';

/// Uma linha da quebra do preço: o que cabe a cada rubrica no preço
/// **esperado** (sugerido pelos percentuais) e no preço **real** (o de venda
/// praticado). `real*` é `null` enquanto não há preço de venda.
class LinhaQuebra {
  const LinhaQuebra({
    required this.nome,
    required this.esperado,
    required this.esperadoPct,
    this.real,
    this.realPct,
  });

  final String nome;
  final double esperado;
  final double esperadoPct;
  final double? real;
  final double? realPct;
}

/// Quebra comparada: linhas + os dois preços. Tudo **sem IVA** — o IVA é
/// cobrado em cima do preço limpo, por isso soma-se no fim ([ivaPct]).
class QuebraComparada {
  const QuebraComparada({
    required this.linhas,
    required this.precoEsperado,
    this.precoReal,
    this.ivaPct = 0,
  });

  final List<LinhaQuebra> linhas;

  /// Preço sugerido pelos percentuais, sem IVA.
  final double precoEsperado;

  /// Preço de venda praticado, sem IVA (`null` se ainda não há preço).
  final double? precoReal;

  /// Taxa de IVA (%); 0 = não definida.
  final double ivaPct;

  double get precoEsperadoComIva => precoEsperado * (1 + ivaPct / 100);
  double? get precoRealComIva =>
      precoReal == null ? null : precoReal! * (1 + ivaPct / 100);
}

/// Percentuais de custo da empresa (tabela `configuracoes_custo`).
///
/// A ideia (portada do `meu_app_ia`): tudo o que não é matéria-prima soma uma
/// percentagem do preço de venda; o que sobra é o CMV (custo da matéria-prima
/// como % do preço). Logo `preço de venda = custo / (CMV% / 100)`.
@freezed
class CostConfig with _$CostConfig {
  const factory CostConfig({
    String? id,
    @Default(0) double salario,
    @Default(0) double aluguel,
    @Default(0) double impostos,
    @Default(0) double servicos,
    @Default(0) double despesasFixas,
    @Default(0) double taxasFinanceiras,
    @Default(0) double margemLucro,

    /// Taxa de IVA das vendas (%). 0 = não definida. Não faz parte da quebra
    /// do preço (não entra em [somaOutros]): o IVA soma-se no fim, sobre o
    /// preço sem IVA. Também estima o IVA quando a venda não traz o valor
    /// sem IVA.
    @Default(0) double ivaVendas,
  }) = _CostConfig;

  const CostConfig._();

  factory CostConfig.fromRecord(RecordModel r) => CostConfig(
    id: r.id,
    salario: r.getDoubleValue('salario'),
    aluguel: r.getDoubleValue('aluguel'),
    impostos: r.getDoubleValue('impostos'),
    servicos: r.getDoubleValue('servicos_e_gastos_intangiveis'),
    despesasFixas: r.getDoubleValue('despesas_fixas'),
    taxasFinanceiras: r.getDoubleValue('taxas_financeiras'),
    margemLucro: r.getDoubleValue('margem_de_lucro'),
    ivaVendas: r.getDoubleValue('iva_vendas'),
  );

  Map<String, dynamic> toBody() => {
    'salario': salario,
    'aluguel': aluguel,
    'impostos': impostos,
    'servicos_e_gastos_intangiveis': servicos,
    'despesas_fixas': despesasFixas,
    'taxas_financeiras': taxasFinanceiras,
    'margem_de_lucro': margemLucro,
    'iva_vendas': ivaVendas,
  };

  /// Rubricas nomeadas (para a quebra do preço).
  Map<String, double> get rubricas => {
    'Salário': salario,
    'Aluguel': aluguel,
    'Impostos': impostos,
    'Serviços e gastos intangíveis': servicos,
    'Despesas fixas': despesasFixas,
    'Taxas financeiras': taxasFinanceiras,
    'Margem de lucro': margemLucro,
  };

  double get somaOutros => rubricas.values.fold(0, (s, v) => s + v);

  /// CMV (matéria-prima) como % do preço de venda.
  double get cmvPercent => 100 - somaOutros;

  double get _fatorIva => 1 + (ivaVendas < 0 ? 0 : ivaVendas) / 100;

  /// Preço sem IVA a partir do preço com IVA (o que o cliente paga).
  double semIva(double comIva) => comIva / _fatorIva;

  /// Preço com IVA a partir do preço sem IVA: o IVA soma-se por último.
  double comIva(double semIva) => semIva * _fatorIva;

  /// Preço sugerido já com IVA (para comparar com o preço de venda ao
  /// público).
  double precoSugeridoComIva(double custoMateriaPrima) =>
      comIva(precoSugerido(custoMateriaPrima));

  /// Preço mínimo **sem IVA** em que a margem de lucro é zero: abaixo disto
  /// há prejuízo. As outras rubricas mantêm o seu percentual do preço.
  double precoEquilibrio(double custoMateriaPrima) {
    final fator = 1 - (somaOutros - margemLucro) / 100;
    return fator <= 0 ? 0 : custoMateriaPrima / fator;
  }

  /// Lucro por unidade (€) a um dado preço **sem IVA**.
  double lucroSemIva(double custoMateriaPrima, double precoSemIva) =>
      precoSemIva * (1 - (somaOutros - margemLucro) / 100) - custoMateriaPrima;

  /// Preço de venda sugerido (**sem IVA**) para um dado custo de
  /// matéria-prima.
  double precoSugerido(double custoMateriaPrima) {
    final cmv = cmvPercent;
    if (cmv <= 0) return 0;
    return custoMateriaPrima / (cmv / 100);
  }

  /// Quebra do preço esperado (percentuais) lado a lado com a do preço real.
  ///
  /// [precoVendaComIva] é o preço ao público (com IVA); a quebra faz-se sobre
  /// o preço **sem IVA** e o IVA soma-se no fim.
  /// No real, a matéria-prima é o custo verdadeiro e as rubricas mantêm o seu
  /// percentual do preço sem IVA; a **margem de lucro** é o que sobra
  /// (positiva ou negativa) — assim as linhas somam o preço sem IVA.
  ///
  /// [custoEmbalagem] (parte de [custo]) aparece numa linha à parte, abaixo
  /// da matéria-prima.
  QuebraComparada quebraComparada(
    double custo,
    double precoVendaComIva, {
    double custoEmbalagem = 0,
  }) {
    final esperado = precoSugerido(custo);
    final temReal = precoVendaComIva > 0;
    final precoVenda = temReal ? semIva(precoVendaComIva) : 0.0;
    final emb = custoEmbalagem.clamp(0, custo).toDouble();
    final mp = custo - emb;
    double pctEsperado(double v) =>
        emb == 0 ? cmvPercent : (esperado > 0 ? v / esperado * 100 : 0.0);
    LinhaQuebra linhaCusto(String nome, double v) => LinhaQuebra(
      nome: nome,
      esperado: v,
      esperadoPct: pctEsperado(v),
      real: temReal ? v : null,
      realPct: temReal ? v / precoVenda * 100 : null,
    );
    final linhas = <LinhaQuebra>[
      linhaCusto('Matéria-prima', mp),
      if (emb > 0) linhaCusto('Embalagem', emb),
    ];
    var somaOutrosReal = 0.0;
    for (final e in rubricas.entries) {
      final eMargem = e.key == 'Margem de lucro';
      double? real;
      double? realPct;
      if (temReal) {
        if (eMargem) {
          // preenchido depois, com o que sobra
        } else {
          real = precoVenda * e.value / 100;
          realPct = e.value;
          somaOutrosReal += real;
        }
      }
      linhas.add(
        LinhaQuebra(
          nome: e.key,
          esperado: esperado * e.value / 100,
          esperadoPct: e.value,
          real: real,
          realPct: realPct,
        ),
      );
    }
    if (temReal) {
      final i = linhas.indexWhere((l) => l.nome == 'Margem de lucro');
      final sobra = precoVenda - custo - somaOutrosReal;
      final antiga = linhas[i];
      linhas[i] = LinhaQuebra(
        nome: antiga.nome,
        esperado: antiga.esperado,
        esperadoPct: antiga.esperadoPct,
        real: sobra,
        realPct: sobra / precoVenda * 100,
      );
    }
    return QuebraComparada(
      linhas: linhas,
      precoEsperado: esperado,
      precoReal: temReal ? precoVenda : null,
      ivaPct: ivaVendas < 0 ? 0 : ivaVendas,
    );
  }

  /// Quebra do preço: quanto cada rubrica representa em euros.
  Map<String, double> quebra(double custoMateriaPrima) {
    final preco = precoSugerido(custoMateriaPrima);
    return {
      'Matéria-prima': custoMateriaPrima,
      for (final e in rubricas.entries) e.key: preco * e.value / 100,
    };
  }
}
