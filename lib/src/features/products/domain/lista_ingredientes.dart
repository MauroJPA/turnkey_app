/// Um ingrediente (já em bruto, sem sub-receitas) de um produto, com o peso
/// que leva e os alergénios que contém.
class IngredienteRotulo {
  const IngredienteRotulo({
    required this.nome,
    required this.gramas,
    this.alergenios = const [],
    this.marca = '',
    this.nomeRotulo = '',
  });

  /// Nome completo, como está no ingrediente (pode ter %, marca, "congelado").
  final String nome;
  final double gramas;
  final List<String> alergenios;
  final String marca;

  /// Nome curto/genérico escolhido para a lista resumida (opcional).
  final String nomeRotulo;

  /// Nome para a lista **completa**: o nome do ingrediente e, se a marca ainda
  /// não estiver lá, acrescenta-se no fim.
  String get nomeCompleto {
    final m = marca.trim();
    if (m.isEmpty || _norm(nome).contains(_norm(m))) return nome;
    return '$nome $m';
  }
}

/// Um pedaço de texto da lista, a negrito ou não (os alergénios vão a negrito
/// e em maiúsculas — Reg. (UE) 1169/2011, art. 21).
class SegmentoTexto {
  const SegmentoTexto(this.texto, {this.negrito = false});
  final String texto;
  final bool negrito;
}

/// Lista de ingredientes de um produto: por **ordem decrescente de peso**, com
/// os alergénios destacados. Ingredientes com o mesmo nome somam-se.
///
/// Há duas versões: a **completa** (nome de cada ingrediente tal como é, com
/// marca, percentagens e "congelado") e a **resumida** ([resumida]: nomes
/// curtos e genéricos, variantes juntas — para caber em etiquetas pequenas).
class ListaIngredientes {
  const ListaIngredientes(this.itens);

  final List<IngredienteRotulo> itens;

  bool get vazia => itens.isEmpty;

  factory ListaIngredientes.de(Iterable<IngredienteRotulo> brutos) {
    final porNome = <String, IngredienteRotulo>{};
    for (final b in brutos) {
      final nome = b.nome.trim();
      if (nome.isEmpty || b.gramas <= 0) continue;
      final chave = nome.toLowerCase();
      final atual = porNome[chave];
      if (atual == null) {
        porNome[chave] = IngredienteRotulo(
          nome: nome,
          gramas: b.gramas,
          alergenios: [...b.alergenios],
          marca: b.marca,
          nomeRotulo: b.nomeRotulo,
        );
      } else {
        porNome[chave] = IngredienteRotulo(
          nome: atual.nome,
          gramas: atual.gramas + b.gramas,
          alergenios: {...atual.alergenios, ...b.alergenios}.toList(),
          marca: atual.marca,
          nomeRotulo: atual.nomeRotulo,
        );
      }
    }
    return ListaIngredientes(_ordenar(porNome.values.toList()));
  }

  static List<IngredienteRotulo> _ordenar(List<IngredienteRotulo> l) => l
    ..sort((a, b) {
      final c = b.gramas.compareTo(a.gramas);
      return c != 0 ? c : a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
    });

  /// Todos os alergénios presentes nos ingredientes.
  Set<String> get alergenios => {for (final i in itens) ...i.alergenios};

  /// Versão **resumida**: nomes curtos e genéricos (o `nomeRotulo` do
  /// ingrediente ou, sem ele, um nome deduzido), juntando os que ficam
  /// iguais (ex. "Sumo de Limão" + "Raspas de Limão" = "Limão") e as
  /// variantes de cor (ex. "Açucar Amarelo" + "Açucar Branco" = "Açucar
  /// amarelo e branco"). A ordem continua a ser por peso.
  ListaIngredientes resumida() {
    final grupos = <String, IngredienteRotulo>{};
    for (final i in itens) {
      final curto = i.nomeRotulo.trim().isNotEmpty
          ? i.nomeRotulo.trim()
          : nomeCurtoAuto(i.nome, marca: i.marca);
      final chave = _norm(curto);
      final atual = grupos[chave];
      grupos[chave] = atual == null
          ? IngredienteRotulo(
              nome: curto,
              gramas: i.gramas,
              alergenios: [...i.alergenios],
            )
          : IngredienteRotulo(
              nome: atual.nome,
              gramas: atual.gramas + i.gramas,
              alergenios: {...atual.alergenios, ...i.alergenios}.toList(),
            );
    }
    return ListaIngredientes(
      _ordenar(_juntarVariantes(_ordenar(grupos.values.toList()))),
    );
  }

  static const _variantes = {
    'amarelo', 'branco', 'castanho', 'mascavado', 'negro', 'escuro', 'claro',
  };

  /// "Açucar Amarelo" + "Açucar Branco" → "Açucar amarelo e branco".
  static List<IngredienteRotulo> _juntarVariantes(List<IngredienteRotulo> l) {
    final porBase = <String, List<int>>{};
    for (var i = 0; i < l.length; i++) {
      final p = l[i].nome.trim().split(RegExp(r'\s+'));
      if (p.length == 2 && _variantes.contains(_norm(p[1]))) {
        porBase.putIfAbsent(_norm(p[0]), () => []).add(i);
      }
    }
    final remover = <int>{};
    final resultado = <int, IngredienteRotulo>{};
    for (final idx in porBase.values) {
      if (idx.length < 2) continue;
      final primeiro = l[idx.first]; // o mais pesado (lista já ordenada)
      final base = primeiro.nome.trim().split(RegExp(r'\s+')).first;
      final adj = [
        for (final i in idx) l[i].nome.trim().split(RegExp(r'\s+')).last.toLowerCase(),
      ];
      final texto = adj.length == 2
          ? '${adj[0]} e ${adj[1]}'
          : '${adj.sublist(0, adj.length - 1).join(', ')} e ${adj.last}';
      resultado[idx.first] = IngredienteRotulo(
        nome: '$base $texto',
        gramas: idx.fold(0.0, (s, i) => s + l[i].gramas),
        alergenios: {for (final i in idx) ...l[i].alergenios}.toList(),
      );
      remover.addAll(idx.skip(1));
    }
    return [
      for (var i = 0; i < l.length; i++)
        if (!remover.contains(i)) resultado[i] ?? l[i],
    ];
  }

  /// O texto da lista em pedaços (para mostrar com negrito). Se o próprio nome
  /// já contém o alergénio ("Leite condensado", "Ovo líquido"), é essa palavra
  /// que fica destacada, sem repetir entre parênteses; os restantes alergénios
  /// vão a seguir, entre parênteses.
  List<SegmentoTexto> get segmentos {
    final out = <SegmentoTexto>[];
    for (var i = 0; i < itens.length; i++) {
      final it = itens[i];
      if (i > 0) out.add(const SegmentoTexto(', '));
      final nome = _capitalizar(it.nomeCompleto, primeiro: i == 0);
      final noNome = <({int ini, int fim})>[];
      final fora = <String>[];
      for (final a in it.alergenios) {
        final m = _acharNoNome(nome, a);
        if (m != null && !noNome.any((r) => m.ini < r.fim && r.ini < m.fim)) {
          noNome.add(m);
        } else {
          fora.add(a);
        }
      }
      noNome.sort((a, b) => a.ini.compareTo(b.ini));
      var pos = 0;
      for (final r in noNome) {
        if (r.ini > pos) out.add(SegmentoTexto(nome.substring(pos, r.ini)));
        out.add(SegmentoTexto(nome.substring(r.ini, r.fim).toUpperCase(), negrito: true));
        pos = r.fim;
      }
      if (pos < nome.length) out.add(SegmentoTexto(nome.substring(pos)));
      if (fora.isNotEmpty) {
        out.add(const SegmentoTexto(' ('));
        for (var j = 0; j < fora.length; j++) {
          if (j > 0) out.add(const SegmentoTexto(', '));
          out.add(SegmentoTexto(fora[j].toUpperCase(), negrito: true));
        }
        out.add(const SegmentoTexto(')'));
      }
    }
    return out;
  }

  /// Onde, no [nome], aparece o próprio alergénio como palavra inteira
  /// (singular ou plural: "Ovos" encontra "Ovo").
  static ({int ini, int fim})? _acharNoNome(String nome, String alergenio) {
    var radical = _norm(alergenio);
    if (radical.length > 3 && radical.endsWith('s')) {
      radical = radical.substring(0, radical.length - 1);
    }
    for (final m in RegExp(r'[\p{L}\p{N}]+', unicode: true).allMatches(nome)) {
      final t = _norm(m.group(0)!);
      if (t == radical || t == '${radical}s') return (ini: m.start, fim: m.end);
    }
    return null;
  }

  /// A mesma lista em texto simples (alergénios em MAIÚSCULAS, para quando não
  /// há negrito, como numa etiqueta térmica).
  String get textoSimples => segmentos.map((s) => s.texto).join();

  static String _capitalizar(String s, {required bool primeiro}) {
    if (!primeiro || s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

/// Nome curto deduzido de um ingrediente, para a lista resumida: tira a marca,
/// percentagens (`30%`), "congelado/a", "líquido/a", "iodado/a", "em pó" e
/// códigos tipo `T55`; e "Sumo/Raspas/Casca/Polpa de X" fica só "X".
String nomeCurtoAuto(String nome, {String marca = ''}) {
  var s = nome.trim();
  final m = marca.trim();
  if (m.isNotEmpty) {
    s = s.replaceAll(RegExp(RegExp.escape(m), caseSensitive: false), ' ');
  }
  s = s
      .replaceAll(RegExp(r'\d+(?:[.,]\d+)?\s*%'), ' ')
      .replaceAll(RegExp(r'\bt\d{2,3}\b', caseSensitive: false), ' ')
      .replaceAll(
        RegExp(
          r'\b(congelad[oa]s?|l[ií]quid[oa]s?|iodad[oa]s?|pasteurizad[oa]s?)\b',
          caseSensitive: false,
        ),
        ' ',
      )
      .replaceAll(RegExp(r'\bem p[óo](?=\s|$)', caseSensitive: false), ' ')
      .replaceFirst(
        RegExp(
          r'^\s*(sumo|suco|raspas?|casca|polpa|pur[ée])\s+de\s+',
          caseSensitive: false,
        ),
        '',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (s.isEmpty) return nome.trim();
  if (_norm(s) == 'ovo') return 'Ovos';
  return s;
}

/// Minúsculas sem acentos (para comparar nomes).
String _norm(String s) {
  const de = 'áàãâäéèêëíìîïóòõôöúùûüçñ';
  const para = 'aaaaaeeeeiiiiooooouuuucn';
  final b = StringBuffer();
  for (final c in s.toLowerCase().trim().split('')) {
    final i = de.indexOf(c);
    b.write(i >= 0 ? para[i] : c);
  }
  return b.toString();
}
