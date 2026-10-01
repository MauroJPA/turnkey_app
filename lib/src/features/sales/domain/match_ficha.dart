import '../../tech_sheets/domain/tech_sheet.dart';

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

Set<String> _tokens(String s) => _normalizar(s)
    .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
    .split(RegExp(r'\s+'))
    .where((t) => t.length > 2)
    .toSet();

/// Pontuação de semelhança entre uma descrição de linha de venda (CSV/Vendus)
/// e uma ficha técnica — mesma lógica de `match_ingrediente.dart` (Jaccard
/// sobre tokens, sem acentos), agora sobre `nome`/`categoria` da ficha.
double scoreMatchFicha(String descricaoVenda, FichaTecnica ficha) {
  final a = _tokens(descricaoVenda);
  final b = _tokens('${ficha.nome} ${ficha.categoria}');
  if (a.isEmpty || b.isEmpty) return 0;
  final inter = a.intersection(b).length;
  final uni = a.union(b).length;
  return inter / uni;
}

/// Melhor ficha técnica para uma descrição de linha de venda, ou `null` se
/// nada bater com confiança suficiente.
FichaTecnica? melhorMatchFicha(
  String descricaoVenda,
  List<FichaTecnica> todas, {
  double minScore = 0.34,
}) {
  FichaTecnica? melhor;
  var melhorScore = 0.0;
  for (final f in todas) {
    final s = scoreMatchFicha(descricaoVenda, f);
    if (s > melhorScore) {
      melhorScore = s;
      melhor = f;
    }
  }
  return melhorScore >= minScore ? melhor : null;
}

/// Como o servidor compara descrições de venda já ligadas manualmente a uma
/// ficha (`nomesVenda`): mesma normalização de `_normalizar`, espaços simples.
String normalizarDescricaoVenda(String s) =>
    _normalizar(s).replaceAll(RegExp(r'\s+'), ' ').trim();

/// Ficha técnica para uma descrição de linha de venda — por ordem:
/// 1) esta descrição já foi ligada manualmente a uma ficha antes (aprendido
///    em `fichas_tecnicas.nomes_venda`, ver "ligar produto" em Vendas);
/// 2) semelhança de palavras com o nome/categoria da ficha (`melhorMatchFicha`).
FichaTecnica? fichaParaVenda(
  String descricaoVenda,
  List<FichaTecnica> todas, {
  double minScore = 0.34,
}) {
  final desc = normalizarDescricaoVenda(descricaoVenda);
  for (final f in todas) {
    if (f.nomesVenda.contains(desc)) return f;
  }
  return melhorMatchFicha(descricaoVenda, todas, minScore: minScore);
}
