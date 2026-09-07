import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'cost_config.freezed.dart';

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
      );

  Map<String, dynamic> toBody() => {
        'salario': salario,
        'aluguel': aluguel,
        'impostos': impostos,
        'servicos_e_gastos_intangiveis': servicos,
        'despesas_fixas': despesasFixas,
        'taxas_financeiras': taxasFinanceiras,
        'margem_de_lucro': margemLucro,
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

  /// Quebra do preço: quanto cada rubrica representa em euros.
  Map<String, double> quebra(double custoMateriaPrima) {
    final preco = precoSugerido(custoMateriaPrima);
    return {
      'Matéria-prima': custoMateriaPrima,
      for (final e in rubricas.entries) e.key: preco * e.value / 100,
    };
  }
}
