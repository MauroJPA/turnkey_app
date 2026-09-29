/// Minúsculas e sem acentos — para comparar/procurar texto sem exigir que a
/// pessoa escreva a acentuação exata (ex.: "acucar" encontra "Açúcar").
String normalizarBusca(String s) {
  const acentos = {
    'á': 'a',
    'à': 'a',
    'ã': 'a',
    'â': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'õ': 'o',
    'ô': 'o',
    'ö': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    'ñ': 'n',
  };
  var out = s.toLowerCase().trim();
  acentos.forEach((k, v) => out = out.replaceAll(k, v));
  return out;
}

/// [texto] contém [query], ignorando maiúsculas/minúsculas e acentuação.
/// Uma [query] vazia corresponde sempre.
bool correspondeABusca(String texto, String query) {
  final q = normalizarBusca(query);
  if (q.isEmpty) return true;
  return normalizarBusca(texto).contains(q);
}
