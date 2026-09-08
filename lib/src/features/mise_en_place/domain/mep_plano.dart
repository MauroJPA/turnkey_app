/// Mise en place de uma receita (resposta de `GET /api/turnkey/receitas/{id}/plano`).
class MepIngrediente {
  const MepIngrediente({
    required this.ingredienteId,
    required this.nome,
    required this.gramas,
    this.emStock = 0,
  });

  final String ingredienteId;
  final String nome;
  final double gramas;
  final double emStock;

  bool get faltaStock => emStock < gramas;

  factory MepIngrediente.fromJson(Map<String, dynamic> j) => MepIngrediente(
        ingredienteId: j['ingredienteId'] as String? ?? '',
        nome: j['nome'] as String? ?? '',
        gramas: (j['gramas'] as num?)?.toDouble() ?? 0,
        emStock: (j['emStock'] as num?)?.toDouble() ?? 0,
      );
}

class MepIntermedio {
  const MepIntermedio({
    required this.receitaId,
    required this.nome,
    required this.gramas,
  });

  final String receitaId;
  final String nome;
  final double gramas;

  factory MepIntermedio.fromJson(Map<String, dynamic> j) => MepIntermedio(
        receitaId: j['receitaId'] as String? ?? '',
        nome: j['nome'] as String? ?? '',
        gramas: (j['gramas'] as num?)?.toDouble() ?? 0,
      );
}

class MepPlano {
  const MepPlano({
    required this.receitaId,
    required this.nome,
    required this.kg,
    this.unidades = 0,
    this.formato = '',
    this.recheio = '',
    this.comprar = const [],
    this.intermedios = const [],
  });

  final String receitaId;
  final String nome;
  final double kg;
  final int unidades;
  final String formato;
  final String recheio;
  final List<MepIngrediente> comprar;
  final List<MepIntermedio> intermedios;

  factory MepPlano.fromJson(Map<String, dynamic> j) => MepPlano(
        receitaId: j['receitaId'] as String? ?? '',
        nome: j['nome'] as String? ?? '',
        kg: (j['kg'] as num?)?.toDouble() ?? 0,
        unidades: (j['unidades'] as num?)?.toInt() ?? 0,
        formato: j['formato'] as String? ?? '',
        recheio: j['recheio'] as String? ?? '',
        comprar: ((j['comprar'] as List?) ?? const [])
            .map((e) =>
                MepIngrediente.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        intermedios: ((j['intermedios'] as List?) ?? const [])
            .map((e) =>
                MepIntermedio.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}
