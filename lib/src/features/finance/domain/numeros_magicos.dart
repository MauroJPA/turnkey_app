import 'periodo.dart';

/// "Números mágicos": o ponto a partir do qual tudo o que se vender é
/// lucro, porque os custos reais + imposto + CMV já estão cobertos.
class NumerosMagicos {
  const NumerosMagicos({
    required this.periodo,
    required this.custosFixosMensal,
    required this.custosVariaveisMensal,
    required this.depreciacaoMensal,
    required this.impostoPercent,
    required this.cmvPercent,
    required this.receitaPeriodo,
    this.diasUteisMes = 26,
  });

  final Periodo periodo;

  /// Custos fixos/variáveis/depreciação ativos — valor mensal cheio (não
  /// prorateado), porque a venda mínima é sempre um alvo mensal.
  final double custosFixosMensal;
  final double custosVariaveisMensal;
  final double depreciacaoMensal;

  /// Percentuais de `Configurações → Percentuais de custo`.
  final double impostoPercent;
  final double cmvPercent;

  /// Receita real do [periodo] escolhido, só para comparar com o alvo.
  final double receitaPeriodo;

  final int diasUteisMes;

  double get custosReaisMensais =>
      custosFixosMensal + custosVariaveisMensal + depreciacaoMensal;

  /// % da receita que fica livre depois de imposto + CMV, para cobrir os
  /// custos reais (e, a partir daí, ser lucro).
  double get margemLivrePercent => 100 - impostoPercent - cmvPercent;

  /// `null` se imposto+CMV somarem 100% ou mais — não há venda que cubra
  /// os custos nessas condições.
  double? get vendaMinimaMensal => margemLivrePercent > 0
      ? custosReaisMensais / (margemLivrePercent / 100)
      : null;

  double? get vendaMinimaDiaria =>
      vendaMinimaMensal == null ? null : vendaMinimaMensal! / diasUteisMes;

  /// A venda mínima mensal, na proporção da duração do [periodo] escolhido
  /// — para comparar com [receitaPeriodo].
  double? get vendaMinimaDoPeriodo => vendaMinimaMensal == null
      ? null
      : vendaMinimaMensal! * periodo.fatorProrateioMensal;

  /// Positivo = falta vender para bater o mínimo do período; negativo = já
  /// passou o mínimo (o excedente é lucro puro).
  double? get faltaParaMinimo => vendaMinimaDoPeriodo == null
      ? null
      : vendaMinimaDoPeriodo! - receitaPeriodo;
}
