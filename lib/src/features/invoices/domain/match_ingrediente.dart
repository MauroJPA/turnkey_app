import '../../ingredients/domain/ingredient.dart';

String _normalizar(String s) {
  const acentos = {
    'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a', 'ä': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e',
    'í': 'i', 'ì': 'i',
    'ó': 'o', 'ò': 'o', 'õ': 'o', 'ô': 'o',
    'ú': 'u', 'ù': 'u', 'ü': 'u',
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
  if (ing.marca.isNotEmpty &&
      descNorm.contains(_normalizar(ing.marca))) {
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
