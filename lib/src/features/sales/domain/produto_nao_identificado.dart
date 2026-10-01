import 'venda.dart';

/// Todas as linhas de venda (de qualquer venda) com esta descrição exata,
/// ainda sem ficha técnica associada — para ligar de uma vez a um produto.
class ProdutoNaoIdentificado {
  const ProdutoNaoIdentificado({
    required this.descricao,
    required this.linhas,
    required this.quantidade,
    required this.total,
  });

  final String descricao;

  /// Nº de linhas de venda (em vendas diferentes, possivelmente) com esta
  /// descrição e sem ficha.
  final int linhas;
  final double quantidade;
  final double total;
}

/// Agrupa as linhas de venda sem ficha por descrição exata — ordenado por
/// valor total, decrescente (as mais relevantes primeiro).
List<ProdutoNaoIdentificado> agruparSemFicha(List<VendaItem> itens) {
  final porDescricao = <String, ({int linhas, double quantidade, double total})>{};
  for (final it in itens) {
    if (it.temFicha) continue;
    final chave = it.descricao;
    final atual = porDescricao[chave];
    porDescricao[chave] = (
      linhas: (atual?.linhas ?? 0) + 1,
      quantidade: (atual?.quantidade ?? 0) + it.quantidade,
      total: (atual?.total ?? 0) + it.totalLinha,
    );
  }
  final lista = porDescricao.entries
      .map((e) => ProdutoNaoIdentificado(
            descricao: e.key,
            linhas: e.value.linhas,
            quantidade: e.value.quantidade,
            total: e.value.total,
          ))
      .toList()
    ..sort((a, b) => b.total.compareTo(a.total));
  return lista;
}
