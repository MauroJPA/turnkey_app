import '../../sales/domain/venda.dart';
import 'periodo.dart';

/// Soma o total das vendas de cada dia.
Map<DateTime, double> vendidoPorDia(Iterable<Venda> vendas) {
  final out = <DateTime, double>{};
  for (final v in vendas) {
    final d = DateTime(v.data.year, v.data.month, v.data.day);
    out[d] = (out[d] ?? 0) + v.total;
  }
  return out;
}

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
    this.periodoComparado,
    this.receitaComparada = 0,
    this.vendasPorDia = const {},
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

  /// Intervalo do período anterior usado na comparação — se o período atual
  /// ainda está a decorrer, é só o mesmo nº de dias do anterior (para comparar
  /// o mesmo ponto); senão, o período anterior completo. `null` = sem dados.
  final Periodo? periodoComparado;

  /// Receita nesse [periodoComparado].
  final double receitaComparada;

  final int diasUteisMes;

  /// Vendido em cada dia do [periodo] (só os dias com vendas).
  final Map<DateTime, double> vendasPorDia;

  /// Variação do vendido face ao [periodoComparado], em % (`null` se não há
  /// nada vendido nesse período para comparar).
  double? get variacaoVendidoPercent =>
      periodoComparado == null || receitaComparada <= 0
      ? null
      : (receitaPeriodo / receitaComparada - 1) * 100;

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
  double? get vendaMinimaDoPeriodo {
    if (vendaMinimaMensal == null) return null;
    // um único dia: a venda mínima diária (mensal ÷ dias de trabalho)
    if (periodo.tipo == TipoPeriodo.dia) return vendaMinimaDiaria;
    return vendaMinimaMensal! * periodo.fatorProrateioMensal;
  }

  /// Positivo = falta vender para bater o mínimo do período; negativo = já
  /// passou o mínimo (o excedente é lucro puro).
  double? get faltaParaMinimo => vendaMinimaDoPeriodo == null
      ? null
      : vendaMinimaDoPeriodo! - receitaPeriodo;

  /// Venda acima do mínimo do período (0 se ainda não o atingiu). Não é lucro:
  /// cada euro vendido a mais continua a levar imposto e CMV.
  double get vendidoAcimaDoMinimo {
    final falta = faltaParaMinimo;
    return falta == null || falta >= 0 ? 0 : -falta;
  }

  /// Imposto devido sobre o que se vendeu acima do mínimo.
  double get impostoSobreExcedente =>
      vendidoAcimaDoMinimo * impostoPercent / 100;

  /// Custo da matéria-prima (CMV) dos produtos vendidos acima do mínimo.
  double get cmvSobreExcedente => vendidoAcimaDoMinimo * cmvPercent / 100;

  /// Lucro líquido do período: o que sobra do excedente depois de imposto e
  /// CMV (os custos reais já ficaram pagos pelo mínimo).
  double get lucroLiquidoPeriodo =>
      vendidoAcimaDoMinimo - impostoSobreExcedente - cmvSobreExcedente;
}
