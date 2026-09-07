// Modelos de "produção": a receita de um produto escalada para a quantidade
// que se quer produzir.

class ProductionLine {
  ProductionLine({
    required this.nome,
    required this.quantidadeG,
    required this.custo,
    this.pendente = false,
  });

  final String nome;
  final double quantidadeG;
  final double custo;

  /// Linha importada sem vínculo (não entra no custo).
  final bool pendente;
}

class ProductionNode {
  ProductionNode({
    required this.receitaId,
    required this.nome,
    required this.alvoG,
    required this.rendimentoBase,
    required this.linhas,
    required this.subReceitas,
    this.ciclo = false,
  });

  final String receitaId;
  final String nome;

  /// Quantos gramas desta (sub-)receita produzir.
  final double alvoG;

  /// Rendimento base da receita (a que correspondem as quantidades originais).
  final double rendimentoBase;

  final List<ProductionLine> linhas;
  final List<ProductionNode> subReceitas;

  /// Ciclo de sub-receitas detetado — não foi expandido.
  final bool ciclo;

  /// Fator de escala aplicado às quantidades.
  double get fator => rendimentoBase > 0 ? alvoG / rendimentoBase : 0;

  bool get semRendimento => rendimentoBase <= 0;

  double get custoTotal =>
      linhas.fold<double>(0, (s, l) => s + l.custo) +
      subReceitas.fold<double>(0, (s, n) => s + n.custoTotal);

  /// Peso somado das linhas (deve aproximar-se de [alvoG]).
  double get pesoLinhas =>
      linhas.fold<double>(0, (s, l) => s + l.quantidadeG) +
      subReceitas.fold<double>(0, (s, n) => s + n.alvoG);
}
