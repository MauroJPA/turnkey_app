import 'package:pocketbase/pocketbase.dart';

import '../../../core/formatting/quantities.dart';

/// Uma linha da lista de compras.
///
/// Para ingredientes de receita, as quantidades estão em gramas. Para itens
/// manuais (sacos de lixo, sabão, uma tesoura…) a quantidade é um número na
/// [unidade] escolhida (`un`, `kg`, `caixa`, …).
class ShoppingItem {
  const ShoppingItem({
    required this.id,
    this.ingredienteId,
    required this.descricao,
    this.fornecedor = '',
    this.necessariaG = 0,
    this.comprarG = 0,
    this.comprado = false,
    this.producaoId,
    this.embalagemG = 0,
    this.custoEstimado = 0,
    this.notas = '',
    this.unidade = '',
  });

  final String id;
  final String? ingredienteId;
  final String descricao;
  final String fornecedor;
  final double necessariaG;
  final double comprarG;
  final bool comprado;
  final String? producaoId;
  final double embalagemG;
  final double custoEstimado;
  final String notas;

  /// Unidade da quantidade. `''` ou `g` => quantidade em gramas (ingredientes);
  /// caso contrário é um item manual contado nessa unidade.
  final String unidade;

  bool get emGramas => unidade.isEmpty || unidade == 'g';

  bool get manual => ingredienteId == null;

  /// Rótulo do fornecedor para agrupar (nunca vazio).
  String get grupo => fornecedor.trim().isEmpty ? 'Sem fornecedor' : fornecedor;

  /// Nº de embalagens que cobrem `comprarG` (null se não se conhece a embalagem).
  int? get sacos =>
      (emGramas && embalagemG > 0) ? (comprarG / embalagemG).ceil() : null;

  /// Texto da quantidade a comprar, na unidade certa.
  String quantidadeTexto() {
    if (emGramas) return gramasParaTexto(comprarG);
    final n = comprarG == comprarG.roundToDouble()
        ? comprarG.toStringAsFixed(0)
        : comprarG.toString().replaceAll('.', ',');
    return '$n $unidade';
  }

  static String gramasLabel(double g) => gramasParaTexto(g);

  factory ShoppingItem.fromRecord(RecordModel r) {
    final ing = r.getStringValue('ingrediente');
    return ShoppingItem(
      id: r.id,
      ingredienteId: ing.isEmpty ? null : ing,
      descricao: r.getStringValue('descricao'),
      fornecedor: r.getStringValue('fornecedor'),
      necessariaG: r.getDoubleValue('quantidade_necessaria_g'),
      comprarG: r.getDoubleValue('quantidade_comprar_g'),
      comprado: r.getBoolValue('comprado'),
      producaoId: r.getStringValue('producao').isEmpty
          ? null
          : r.getStringValue('producao'),
      embalagemG: r.getDoubleValue('embalagem_g'),
      custoEstimado: r.getDoubleValue('custo_estimado'),
      notas: r.getStringValue('notas'),
      unidade: r.getStringValue('unidade'),
    );
  }

  ShoppingItem copyWith({double? comprarG, bool? comprado}) => ShoppingItem(
        id: id,
        ingredienteId: ingredienteId,
        descricao: descricao,
        fornecedor: fornecedor,
        necessariaG: necessariaG,
        comprarG: comprarG ?? this.comprarG,
        comprado: comprado ?? this.comprado,
        producaoId: producaoId,
        embalagemG: embalagemG,
        custoEstimado: custoEstimado,
        notas: notas,
        unidade: unidade,
      );
}
