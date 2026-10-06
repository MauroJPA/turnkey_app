import '../../ingredients/domain/ingredient.dart';
import '../../ingredients/domain/produto_ingrediente.dart';

/// Preços com mais de [diasPrecoAntigo] dias já não são fiáveis para dizer
/// "este é o mais barato": mostram-se, mas não entram na recomendação.
const diasPrecoAntigo = 150;

/// Só vale a pena trocar de marca/fornecedor se poupar pelo menos isto (%).
const poupancaMinimaPct = 3.0;

/// Uma forma de comprar um ingrediente: um produto (marca/embalagem) de um
/// fornecedor, com o preço por kg (ou litro, ou unidade).
class OpcaoPreco {
  const OpcaoPreco({
    required this.produto,
    required this.custo,
    required this.diasDesdeCompra,
  });

  final ProdutoIngrediente produto;

  /// Preço por kg, por litro ou por unidade (consoante a unidade do ingrediente).
  final double custo;

  /// Dias desde a última compra/preço (null se não há data).
  final int? diasDesdeCompra;

  bool get antigo =>
      diasDesdeCompra != null && diasDesdeCompra! > diasPrecoAntigo;
}

/// As opções de compra de um ingrediente, da mais barata para a mais cara.
class ComparacaoIngrediente {
  const ComparacaoIngrediente({
    required this.ingrediente,
    required this.opcoes,
  });

  final Ingrediente ingrediente;
  final List<OpcaoPreco> opcoes;

  /// "kg", "l" ou "un": a unidade a que o preço se refere.
  String get unidadePreco => switch (ingrediente.un) {
    'ml' => 'l',
    'un' => 'un',
    _ => 'kg',
  };

  /// A mais barata de entre os preços recentes (null se não há nenhum).
  OpcaoPreco? get maisBarata {
    for (final o in opcoes) {
      if (!o.antigo) return o;
    }
    return null;
  }

  /// A que se compra agora: a do preço mais recente.
  OpcaoPreco? get emUso {
    OpcaoPreco? melhor;
    for (final o in opcoes) {
      final d = o.diasDesdeCompra;
      if (d == null) continue;
      if (melhor == null || d < melhor.diasDesdeCompra!) melhor = o;
    }
    return melhor;
  }

  /// Quanto se poupava (%) a comprar a mais barata em vez da que está em uso;
  /// 0 se já é a mais barata ou se a diferença não compensa.
  double get poupancaPct {
    final barata = maisBarata;
    final uso = emUso;
    if (barata == null || uso == null || uso.custo <= 0) return 0;
    if (identical(barata, uso)) return 0;
    final pct = (uso.custo - barata.custo) / uso.custo * 100;
    return pct >= poupancaMinimaPct ? pct : 0;
  }

  /// Poupança em preço por kg/l/un.
  double get poupancaValor {
    final barata = maisBarata;
    final uso = emUso;
    if (barata == null || uso == null || poupancaPct == 0) return 0;
    return uso.custo - barata.custo;
  }

  bool get temPoupanca => poupancaPct > 0;
}

/// Junta os produtos de cada ingrediente e compara-os. Só aparecem ingredientes
/// com **pelo menos duas** opções com preço; ordenados pela maior poupança.
List<ComparacaoIngrediente> compararPrecos({
  required List<Ingrediente> ingredientes,
  required List<ProdutoIngrediente> produtos,
  DateTime? agora,
}) {
  final hoje = agora ?? DateTime.now();
  final porIngrediente = <String, List<ProdutoIngrediente>>{};
  for (final p in produtos) {
    if (!p.temPreco) continue;
    porIngrediente.putIfAbsent(p.ingredienteId, () => []).add(p);
  }
  final out = <ComparacaoIngrediente>[];
  for (final ing in ingredientes) {
    final lista = porIngrediente[ing.id];
    if (lista == null || lista.length < 2) continue;
    final opcoes = [
      for (final p in lista)
        OpcaoPreco(
          produto: p,
          // 'un': custo por unidade; g/ml: por 1000 g ou 1000 ml
          custo: p.custoPorGrama * (ing.un == 'un' ? 1 : 1000),
          diasDesdeCompra: p.precoAtualizadoEm == null
              ? null
              : hoje.difference(p.precoAtualizadoEm!).inDays,
        ),
    ]..sort((a, b) => a.custo.compareTo(b.custo));
    out.add(ComparacaoIngrediente(ingrediente: ing, opcoes: opcoes));
  }
  out.sort((a, b) {
    final c = b.poupancaPct.compareTo(a.poupancaPct);
    return c != 0
        ? c
        : a.ingrediente.nome.toLowerCase().compareTo(
            b.ingrediente.nome.toLowerCase(),
          );
  });
  return out;
}
