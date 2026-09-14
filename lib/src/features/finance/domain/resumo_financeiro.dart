import 'periodo.dart';

/// Resumo financeiro real de um [periodo]: entrada (vendas), saída (custo
/// dos produtos vendidos + custos fixos/variáveis) e lucro.
class ResumoFinanceiro {
  const ResumoFinanceiro({
    required this.periodo,
    required this.receita,
    required this.custoProdutos,
    required this.custosFixos,
    required this.custosVariaveis,
    required this.numVendas,
    required this.numLinhasSemFicha,
    required this.quebra,
  });

  final Periodo periodo;

  /// Total efetivamente recebido (soma das vendas do período).
  final double receita;

  /// Custo real da matéria-prima do que foi vendido (CPV).
  final double custoProdutos;

  /// Custos fixos ativos, prorateados para a duração do período.
  final double custosFixos;

  /// Custos variáveis ativos (`custos_fixos.tipo = variavel`), idem.
  final double custosVariaveis;

  final int numVendas;

  /// Linhas de venda sem ficha técnica associada — o seu custo não entra em
  /// [custoProdutos] (é desconhecido), por isso o lucro fica sobrestimado
  /// nessa medida. Mostrado como aviso.
  final int numLinhasSemFicha;

  /// Distribuição teórica do valor vendido pelas rubricas de
  /// `configuracoes_custo` (percentagens atuais) — "para onde o dinheiro
  /// deveria ir", não o que realmente saiu (isso são [custosFixos]/
  /// [custosVariaveis]).
  final Map<String, double> quebra;

  double get lucroBruto => receita - custoProdutos;
  double get despesasOperacionais => custosFixos + custosVariaveis;
  double get lucroLiquido => receita - custoProdutos - despesasOperacionais;

  double get margemLiquidaPercent =>
      receita > 0 ? (lucroLiquido / receita) * 100 : 0;
}

/// Comparação entre um período e o [anterior], para os cartões de
/// tendência do painel ("+12% vs. período anterior").
class ComparacaoFinanceira {
  const ComparacaoFinanceira({required this.atual, required this.anterior});

  final ResumoFinanceiro atual;
  final ResumoFinanceiro anterior;

  double? get variacaoReceitaPercent => _variacao(
        anterior.receita,
        atual.receita,
      );

  double? get variacaoLucroPercent => _variacao(
        anterior.lucroLiquido,
        atual.lucroLiquido,
      );

  static double? _variacao(double antes, double depois) {
    if (antes == 0) return null;
    return ((depois - antes) / antes.abs()) * 100;
  }
}
