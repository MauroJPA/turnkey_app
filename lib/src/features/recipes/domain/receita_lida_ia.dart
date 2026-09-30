/// Um ingrediente lido de uma imagem (print/foto de uma lista) por IA.
class IngredienteLidoIa {
  const IngredienteLidoIa({required this.nome, required this.quantidadeG});
  final String nome;
  final double quantidadeG;
}

/// Resultado de ler uma imagem de receita por IA (`nome`/`categoria` podem
/// vir vazios se não aparecerem na imagem) — só leitura, nada é gravado;
/// serve para pré-preencher o formulário antes de importar.
class ReceitaLidaIa {
  const ReceitaLidaIa({
    this.nome = '',
    this.categoria = '',
    this.ingredientes = const [],
  });

  final String nome;
  final String categoria;
  final List<IngredienteLidoIa> ingredientes;

  factory ReceitaLidaIa.fromJson(Map<String, dynamic> j) {
    final lista = ((j['ingredientes'] as List?) ?? const [])
        .whereType<Map>()
        .map(
          (m) => IngredienteLidoIa(
            nome: '${m['nome'] ?? ''}'.trim(),
            quantidadeG: (m['quantidade_g'] as num?)?.toDouble() ?? 0,
          ),
        )
        .where((i) => i.nome.isNotEmpty && i.quantidadeG > 0)
        .toList();
    return ReceitaLidaIa(
      nome: '${j['nome'] ?? ''}'.trim(),
      categoria: '${j['categoria'] ?? ''}'.trim(),
      ingredientes: lista,
    );
  }
}
