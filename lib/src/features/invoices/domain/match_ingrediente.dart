import '../../consumables/domain/consumivel.dart';
import '../../ingredients/domain/ingredient.dart';
import '../../ingredients/domain/produto_ingrediente.dart';

String _normalizar(String s) {
  const acentos = {
    'á': 'a',
    'à': 'a',
    'ã': 'a',
    'â': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ó': 'o',
    'ò': 'o',
    'õ': 'o',
    'ô': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'ç': 'c',
  };
  var out = s.toLowerCase();
  acentos.forEach((k, v) => out = out.replaceAll(k, v));
  return out;
}

/// Minúsculas, sem acentos e sem espaços nas pontas — para comparar nomes.
String normalizarNome(String s) => _normalizar(s).trim();

Set<String> _tokens(String s) => _normalizar(s)
    .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
    .split(RegExp(r'\s+'))
    .where((t) => t.length > 2)
    .toSet();

/// Pontuação de semelhança entre uma descrição de fatura e um ingrediente.
double scoreMatch(String descricaoFatura, Ingrediente ing) {
  final a = _tokens(descricaoFatura);
  final b = _tokens('${ing.nome} ${ing.caracteristica}');
  if (a.isEmpty || b.isEmpty) return 0;
  final inter = a.intersection(b).length;
  final uni = a.union(b).length;
  var score = inter / uni; // Jaccard
  final descNorm = _normalizar(descricaoFatura);
  if (ing.marca.isNotEmpty && descNorm.contains(_normalizar(ing.marca))) {
    score += 0.15;
  }
  return score;
}

/// Melhor ingrediente para uma descrição de fatura, ou `null` se nada bate.
Ingrediente? melhorMatch(
  String descricaoFatura,
  List<Ingrediente> todos, {
  double minScore = 0.34,
}) {
  Ingrediente? melhor;
  var melhorScore = 0.0;
  for (final ing in todos) {
    final s = scoreMatch(descricaoFatura, ing);
    if (s > melhorScore) {
      melhorScore = s;
      melhor = ing;
    }
  }
  return melhorScore >= minScore ? melhor : null;
}

/// Como o servidor compara nomes de fatura aprendidos: minúsculas, sem acentos,
/// espaços simples.
String normalizarDescricao(String s) =>
    normalizarNome(s).replaceAll(RegExp(r'\s+'), ' ');

/// Ingrediente genérico (e, se já se conhece, o produto de compra) de uma linha.
typedef MatchLinha = ({Ingrediente ingrediente, ProdutoIngrediente? produto});

/// Produto de [ingrediente] com a mesma [marca] (e a mesma embalagem, se souber).
ProdutoIngrediente? produtoDaMarca(
  Ingrediente ingrediente,
  List<ProdutoIngrediente> produtos, {
  String marca = '',
  double embalagemG = 0,
}) {
  final m = normalizarNome(marca);
  if (m.isEmpty) return null;
  for (final p in produtos) {
    if (p.ingredienteId != ingrediente.id) continue;
    if (normalizarNome(p.marca) != m) continue;
    if (embalagemG > 0 && p.embalagemG > 0 && (p.embalagemG - embalagemG).abs() > 0.5) {
      continue;
    }
    return p;
  }
  return null;
}

/// Liga uma linha de fatura a um ingrediente genérico (e produto), por ordem:
/// 1) o nome desta fatura já associado a um produto (aprendido antes);
/// 2) o nome genérico proposto pela IA coincide com um ingrediente;
/// 3) semelhança de palavras com o nome genérico ou com a descrição.
MatchLinha? emparelharLinha({
  required String descricao,
  String nomeGenerico = '',
  String marca = '',
  double embalagemG = 0,
  required List<Ingrediente> ingredientes,
  required List<ProdutoIngrediente> produtos,
}) {
  final desc = normalizarDescricao(descricao);
  final porId = {for (final i in ingredientes) i.id: i};
  for (final p in produtos) {
    if (p.nomesFatura.contains(desc)) {
      final ing = porId[p.ingredienteId];
      if (ing != null) return (ingrediente: ing, produto: p);
    }
  }
  Ingrediente? ing;
  final ng = normalizarNome(nomeGenerico);
  if (ng.isNotEmpty) {
    for (final i in ingredientes) {
      if (normalizarNome(i.nome) == ng) {
        ing = i;
        break;
      }
    }
    ing ??= melhorMatch(nomeGenerico, ingredientes, minScore: 0.6);
  }
  ing ??= melhorMatch(descricao, ingredientes);
  if (ing == null) return null;
  return (
    ingrediente: ing,
    produto: produtoDaMarca(ing, produtos, marca: marca, embalagemG: embalagemG),
  );
}

/// Liga uma linha de fatura a um produto de limpeza/insumo: primeiro pelo nome
/// de fatura já aprendido, depois por semelhança de palavras com o nome
/// (o nome genérico da IA conta tanto como a descrição).
Consumivel? emparelharConsumivel({
  required String descricao,
  String nomeGenerico = '',
  String marca = '',
  required List<Consumivel> consumiveis,
  double minScore = 0.34,
}) {
  final desc = normalizarDescricao(descricao);
  for (final c in consumiveis) {
    if (c.nomesFatura.contains(desc)) return c;
  }
  Consumivel? melhor;
  var melhorScore = 0.0;
  for (final c in consumiveis) {
    final b = _tokens('${c.nome} ${c.marca}');
    if (b.isEmpty) continue;
    var score = 0.0;
    for (final texto in [descricao, if (nomeGenerico.isNotEmpty) nomeGenerico]) {
      final a = _tokens(texto);
      if (a.isEmpty) continue;
      final j = a.intersection(b).length / a.union(b).length;
      if (j > score) score = j;
    }
    final m = _normalizar(marca.isNotEmpty ? marca : '').trim();
    if (score > 0 &&
        c.marca.isNotEmpty &&
        (_normalizar(descricao).contains(_normalizar(c.marca)) ||
            (m.isNotEmpty && m == _normalizar(c.marca)))) {
      score += 0.15;
    }
    if (score > melhorScore) {
      melhorScore = score;
      melhor = c;
    }
  }
  return melhorScore >= minScore ? melhor : null;
}
