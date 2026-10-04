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

/// Quebra comparada: linhas + os dois preços.
class QuebraComparada {
  const QuebraComparada({
    required this.linhas,
    required this.precoEsperado,
    this.precoReal,
  });

  final List<LinhaQuebra> linhas;
  final double precoEsperado;
  final double? precoReal;
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

    /// Taxa de IVA das vendas (%), para estimar o IVA quando a venda não
    /// traz o valor sem IVA. 0 = não definida. Não faz parte da quebra do
    /// preço (não entra em [somaOutros]).
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

  double get somaOutros =>
      rubricas.values.fold(0, (s, v) => s + v);

  /// CMV (matéria-prima) como % do preço de venda.
  double get cmvPercent => 100 - somaOutros;

  /// Preço de venda sugerido para um dado custo de matéria-prima.
  double precoSugerido(double custoMateriaPrima) {
    final cmv = cmvPercent;
    if (cmv <= 0) return 0;
    return custoMateriaPrima / (cmv / 100);
  }

  /// Quebra do preço esperado (percentuais) lado a lado com a do preço real.
  ///
  /// No real, a matéria-prima é o custo verdadeiro e as rubricas mantêm o seu
  /// percentual do preço de venda; a **margem de lucro** é o que sobra
  /// (positiva ou negativa) — assim as linhas somam o preço de venda.
  QuebraComparada quebraComparada(double custo, double precoVenda) {
    final esperado = precoSugerido(custo);
    final temReal = precoVenda > 0;
    final linhas = <LinhaQuebra>[
      LinhaQuebra(
        nome: 'Matéria-prima',
        esperado: custo,
        esperadoPct: cmvPercent,
        real: temReal ? custo : null,
        realPct: temReal ? custo / precoVenda * 100 : null,
      ),
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
