/// Um ingrediente (já em bruto, sem sub-receitas) de um produto, com o peso
/// que leva e os alergénios que contém.
class IngredienteRotulo {
  const IngredienteRotulo({
    required this.nome,
    required this.gramas,
    this.alergenios = const [],
  });

  final String nome;
  final double gramas;
  final List<String> alergenios;
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
        );
      } else {
        porNome[chave] = IngredienteRotulo(
          nome: atual.nome,
          gramas: atual.gramas + b.gramas,
          alergenios: {...atual.alergenios, ...b.alergenios}.toList(),
        );
      }
    }
    final lista = porNome.values.toList()
      ..sort((a, b) {
        final c = b.gramas.compareTo(a.gramas);
        return c != 0 ? c : a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
      });
    return ListaIngredientes(lista);
  }

  /// Todos os alergénios presentes nos ingredientes.
  Set<String> get alergenios => {for (final i in itens) ...i.alergenios};

  /// O texto da lista em pedaços (para mostrar com negrito).
  List<SegmentoTexto> get segmentos {
    final out = <SegmentoTexto>[];
    for (var i = 0; i < itens.length; i++) {
      final it = itens[i];
      if (i > 0) out.add(const SegmentoTexto(', '));
      out.add(SegmentoTexto(_capitalizar(it.nome, primeiro: i == 0)));
      if (it.alergenios.isNotEmpty) {
        out.add(const SegmentoTexto(' ('));
        for (var j = 0; j < it.alergenios.length; j++) {
          if (j > 0) out.add(const SegmentoTexto(', '));
          out.add(SegmentoTexto(it.alergenios[j].toUpperCase(), negrito: true));
        }
        out.add(const SegmentoTexto(')'));
      }
    }
    return out;
  }

  /// A mesma lista em texto simples (alergénios em MAIÚSCULAS, para quando não
  /// há negrito, como numa etiqueta térmica).
  String get textoSimples => segmentos.map((s) => s.texto).join();

  static String _capitalizar(String s, {required bool primeiro}) {
    if (!primeiro || s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
