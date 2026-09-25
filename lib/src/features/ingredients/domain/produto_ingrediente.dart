import 'package:pocketbase/pocketbase.dart';

/// Um produto de compra de um ingrediente genérico: a marca/embalagem/preço
/// que se compra ("Açúcar Sidul branco 1 kg" é um produto de "Açúcar branco").
class ProdutoIngrediente {
  const ProdutoIngrediente({
    required this.id,
    required this.ingredienteId,
    required this.nome,
    this.marca = '',
    this.fornecedor = '',
    this.embalagemG = 0,
    this.preco = 0,
    this.precoAtualizadoEm,
    this.nomesFatura = const [],
    this.alergenios = const [],
    this.alergeniosTracos = const [],
  });

  final String id;
  final String ingredienteId;
  final String nome;
  final String marca;
  final String fornecedor;
  final double embalagemG;
  final double preco;
  final DateTime? precoAtualizadoEm;

  /// Descrições de fatura (normalizadas) já associadas a este produto.
  final List<String> nomesFatura;

  /// Alergénios EXTRA deste produto: só contam quando uma receita o fixa
  /// (juntam-se aos do ingrediente genérico).
  final List<String> alergenios;
  final List<String> alergeniosTracos;

  bool get temPreco => preco > 0 && embalagemG > 0;

  /// Custo por grama (0 se faltarem dados).
  double get custoPorGrama => temPreco ? preco / embalagemG : 0;

  factory ProdutoIngrediente.fromRecord(RecordModel r) {
    final nomes = r.data['nomes_fatura'];
    List<String> lista(String campo) {
      final v = r.data[campo];
      return v is List ? [for (final a in v) '$a'] : const [];
    }

    return ProdutoIngrediente(
      id: r.id,
      ingredienteId: r.getStringValue('ingrediente'),
      nome: r.getStringValue('nome'),
      marca: r.getStringValue('marca'),
      fornecedor: r.getStringValue('fornecedor'),
      embalagemG: r.getDoubleValue('embalagem_g'),
      preco: r.getDoubleValue('preco'),
      precoAtualizadoEm: DateTime.tryParse(
        r.getStringValue('preco_atualizado_em'),
      ),
      nomesFatura: nomes is List
          ? [for (final n in nomes) n.toString()]
          : const [],
      alergenios: lista('alergenios'),
      alergeniosTracos: lista('alergenios_tracos'),
    );
  }

  /// Descrição curta: "Sidul · 1 kg".
  String get resumo {
    final partes = <String>[
      if (marca.isNotEmpty) marca,
      if (embalagemG > 0)
        embalagemG >= 1000
            ? '${_n(embalagemG / 1000)} kg'
            : '${_n(embalagemG)} g',
    ];
    return partes.isEmpty ? nome : partes.join(' · ');
  }

  static String _n(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(2).replaceAll('.', ',');
}

/// O produto com a compra mais recente (o que dá o custo ao genérico).
ProdutoIngrediente? produtoMaisRecente(Iterable<ProdutoIngrediente> produtos) {
  ProdutoIngrediente? melhor;
  for (final p in produtos) {
    if (!p.temPreco) continue;
    if (melhor == null) {
      melhor = p;
      continue;
    }
    final a = p.precoAtualizadoEm;
    final b = melhor.precoAtualizadoEm;
    if (a != null && (b == null || a.isAfter(b))) melhor = p;
  }
  return melhor;
}
