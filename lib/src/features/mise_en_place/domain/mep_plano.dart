/// Mise en place de uma receita (resposta de `GET /api/gc_turnkey/receitas/{id}/plano`).
class MepIngrediente {
  const MepIngrediente({
    required this.ingredienteId,
    required this.nome,
    required this.gramas,
    this.emStock = 0,
    this.produtoIds = const [],
    this.unidade = 'g',
    double? pesoG,
  }) : pesoG = pesoG ?? gramas;

  /// Peso em gramas (para ordenar a lista de ingredientes do rótulo).
  final double pesoG;

  /// Unidade do ingrediente (`g`, `ml` ou `un`): `gramas` está nela.
  final String unidade;

  /// Produtos de compra fixados nas receitas (para juntar os seus alergénios).
  final List<String> produtoIds;

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
        pesoG: (j['pesoG'] as num?)?.toDouble(),
        unidade: j['unidade'] == 'ml' || j['unidade'] == 'un'
            ? j['unidade'] as String
            : 'g',
        produtoIds: [
          for (final p in (j['produtoIds'] as List? ?? const [])) '$p',
        ],
      );
}

class MepIntermedio {
  const MepIntermedio({
    required this.receitaId,
    required this.nome,
    required this.gramas,
    this.eMassa = false,
  });

  final String receitaId;
  final String nome;
  final double gramas;

  /// É a massa do produto final (a primeira coisa a produzir).
  final bool eMassa;

  factory MepIntermedio.fromJson(Map<String, dynamic> j) => MepIntermedio(
        receitaId: j['receitaId'] as String? ?? '',
        nome: j['nome'] as String? ?? '',
        gramas: (j['gramas'] as num?)?.toDouble() ?? 0,
        eMassa: j['eMassa'] as bool? ?? false,
      );
}

class MepPlano {
  const MepPlano({
    required this.receitaId,
    required this.nome,
    required this.kg,
    this.unidades = 0,
    this.formato = '',
    this.formatoId = '',
    this.recheio = '',
    this.fichaId = '',
    this.comprar = const [],
    this.intermedios = const [],
  });

  final String receitaId;
  final String nome;
  final double kg;
  final int unidades;
  final String formato;
  final String formatoId;
  final String recheio;

  /// Preenchido quando o plano é de um produto final (ficha técnica): então
  /// [receitaId] é a receita da massa e [nome] o nome do produto.
  final String fichaId;
  final List<MepIngrediente> comprar;
  final List<MepIntermedio> intermedios;

  factory MepPlano.fromJson(Map<String, dynamic> j) => MepPlano(
        receitaId: j['receitaId'] as String? ?? '',
        nome: j['nome'] as String? ?? '',
        kg: (j['kg'] as num?)?.toDouble() ?? 0,
        unidades: (j['unidades'] as num?)?.toInt() ?? 0,
        formato: j['formato'] as String? ?? '',
        formatoId: j['formatoId'] as String? ?? '',
        recheio: j['recheio'] as String? ?? '',
        fichaId: j['fichaId'] as String? ?? '',
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
