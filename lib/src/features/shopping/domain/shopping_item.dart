import 'package:pocketbase/pocketbase.dart';

/// Uma linha da lista de compras.
///
/// As quantidades estão sempre em gramas (origem: explosão de ingredientes).
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

  /// Rótulo do fornecedor para agrupar (nunca vazio).
  String get grupo => fornecedor.trim().isEmpty ? 'Sem fornecedor' : fornecedor;

  /// Nº de embalagens que cobrem `comprarG` (null se não se conhece a embalagem).
  int? get sacos =>
      embalagemG > 0 ? (comprarG / embalagemG).ceil() : null;

  static String gramasLabel(double g) => g >= 1000
      ? '${(g / 1000).toStringAsFixed(3)} kg'
      : '${g.toStringAsFixed(0)} g';

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
      );
}
