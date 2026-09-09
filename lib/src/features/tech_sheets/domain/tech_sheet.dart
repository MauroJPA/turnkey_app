import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/nutrition/nutrition.dart';

part 'tech_sheet.freezed.dart';

/// Papel de um item dentro de um produto final.
enum SlotFicha {
  massa,
  recheioBase,
  recheioTop,
  coberturaBase,
  coberturaTop,
  extra;

  static SlotFicha fromApi(String? v) => switch (v) {
        'massa' => SlotFicha.massa,
        'recheio_base' => SlotFicha.recheioBase,
        'recheio_top' => SlotFicha.recheioTop,
        'cobertura_base' => SlotFicha.coberturaBase,
        'cobertura_top' => SlotFicha.coberturaTop,
        _ => SlotFicha.extra,
      };

  String get api => switch (this) {
        SlotFicha.massa => 'massa',
        SlotFicha.recheioBase => 'recheio_base',
        SlotFicha.recheioTop => 'recheio_top',
        SlotFicha.coberturaBase => 'cobertura_base',
        SlotFicha.coberturaTop => 'cobertura_top',
        SlotFicha.extra => 'extra',
      };

  String get label => switch (this) {
        SlotFicha.massa => 'Massa',
        SlotFicha.recheioBase => 'Recheio (base)',
        SlotFicha.recheioTop => 'Recheio (topo)',
        SlotFicha.coberturaBase => 'Cobertura (base)',
        SlotFicha.coberturaTop => 'Cobertura (topo)',
        SlotFicha.extra => 'Extra',
      };
}

@freezed
class FichaTecnica with _$FichaTecnica {
  const factory FichaTecnica({
    required String id,
    required String nome,
    @Default('') String categoria,
    @Default(0) double custoProduto,
    @Default(0) double pesoProduto,
    @Default(false) bool deletado,
    @Default(<String, dynamic>{}) Map<String, dynamic> nutriRaw,
  }) = _FichaTecnica;

  const FichaTecnica._();

  /// Declaração nutricional calculada (por 100 g de produto acabado + por
  /// unidade) e alergénios agregados — ver `NutriCache`.
  NutriCache get nutri => NutriCache.fromJson(nutriRaw);

  factory FichaTecnica.fromRecord(RecordModel r) {
    final rawNutri = r.data['nutri'];
    return FichaTecnica(
      id: r.id,
      nome: r.getStringValue('nome'),
      categoria: r.getStringValue('categoria'),
      custoProduto: r.getDoubleValue('custo_produto'),
      pesoProduto: r.getDoubleValue('peso_produto'),
      deletado: r.getBoolValue('deletado'),
      nutriRaw: rawNutri is Map
          ? Map<String, dynamic>.from(rawNutri)
          : const <String, dynamic>{},
    );
  }
}

class FichaInput {
  FichaInput({required this.nome, this.categoria = ''});

  final String nome;
  final String categoria;

  Map<String, dynamic> toBody() => {
        'nome': nome.trim(),
        'categoria': categoria.trim(),
      };
}
