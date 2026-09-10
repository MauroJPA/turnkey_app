import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/nutrition/nutrition.dart';

part 'ingredient.freezed.dart';

enum OrigemIngrediente {
  comprado,
  fabricoProprio;

  static OrigemIngrediente fromApi(String? v) =>
      v == 'fabrico_proprio' ? OrigemIngrediente.fabricoProprio : OrigemIngrediente.comprado;

  String get api =>
      this == OrigemIngrediente.fabricoProprio ? 'fabrico_proprio' : 'comprado';

  String get label => this == OrigemIngrediente.fabricoProprio
      ? 'Fabrico próprio'
      : 'Comprado';
}

@freezed
class Ingrediente with _$Ingrediente {
  const factory Ingrediente({
    required String id,
    required String nome,
    @Default('') String caracteristica,
    @Default('') String marca,
    @Default('') String fornecedor,
    @Default(0) double preco,
    @Default(0) double gramasEmbalagem,
    DateTime? precoAtualizadoEm,
    @Default(true) bool disponivel,
    @Default(OrigemIngrediente.comprado) OrigemIngrediente origem,
    @Default(false) bool deletado,
    // Nutrição (por 100 g/ml) e alergénios — ver core/nutrition.
    @Default(Nutrientes()) Nutrientes nutri,
    @Default('100g') String nutriBase,
    @Default(1) double nutriDensidade,
    @Default('') String nutriOrigem,
    DateTime? nutriAtualizadoEm,
    @Default(<String>[]) List<String> alergenios,
    @Default(<String>[]) List<String> alergeniosTracos,
  }) = _Ingrediente;

  const Ingrediente._();

  /// Preço por grama — base de todos os cálculos de custo.
  double get custoPorGrama =>
      gramasEmbalagem > 0 ? preco / gramasEmbalagem : 0;

  /// `true` se tem pelo menos os valores nutricionais principais.
  bool get temNutri => !nutri.vazio;

  /// O emparelhamento automático com a INSA não teve a certeza — falta a
  /// pessoa escolher o alimento certo (ou preencher à mão / por foto).
  bool get precisaRevisaoInsa => nutriOrigem == 'insa_revisao';

  factory Ingrediente.fromRecord(RecordModel r) {
    final dataRaw = r.getStringValue('preco_atualizado_em');
    final nutriData = r.getStringValue('nutri_atualizado_em');
    List<String> lista(String campo) {
      final v = r.data[campo];
      return v is List ? v.map((e) => '$e').toList() : const [];
    }

    final base = r.getStringValue('nutri_base');
    final dens = r.getDoubleValue('nutri_densidade');
    return Ingrediente(
      id: r.id,
      nome: r.getStringValue('nome'),
      caracteristica: r.getStringValue('caracteristica'),
      marca: r.getStringValue('marca'),
      fornecedor: r.getStringValue('fornecedor'),
      preco: r.getDoubleValue('preco'),
      gramasEmbalagem: r.getDoubleValue('gramas_embalagem'),
      precoAtualizadoEm: dataRaw.isEmpty ? null : DateTime.tryParse(dataRaw),
      disponivel: r.data['disponivel'] as bool? ?? true,
      origem: OrigemIngrediente.fromApi(r.getStringValue('origem')),
      deletado: r.getBoolValue('deletado'),
      nutri: Nutrientes.fromRecord(r),
      nutriBase: base.isEmpty ? '100g' : base,
      nutriDensidade: dens > 0 ? dens : 1,
      nutriOrigem: r.getStringValue('nutri_origem'),
      nutriAtualizadoEm:
          nutriData.isEmpty ? null : DateTime.tryParse(nutriData),
      alergenios: lista('alergenios'),
      alergeniosTracos: lista('alergenios_tracos'),
    );
  }
}

/// Dados de formulário para criar/editar um ingrediente.
class IngredienteInput {
  IngredienteInput({
    required this.nome,
    this.caracteristica = '',
    this.marca = '',
    this.fornecedor = '',
    this.preco = 0,
    this.gramasEmbalagem = 0,
    this.disponivel = true,
    this.origem = OrigemIngrediente.comprado,
  });

  final String nome;
  final String caracteristica;
  final String marca;
  final String fornecedor;
  final double preco;
  final double gramasEmbalagem;
  final bool disponivel;
  final OrigemIngrediente origem;

  factory IngredienteInput.fromModel(Ingrediente i, {String? nome}) =>
      IngredienteInput(
        nome: nome ?? i.nome,
        caracteristica: i.caracteristica,
        marca: i.marca,
        fornecedor: i.fornecedor,
        preco: i.preco,
        gramasEmbalagem: i.gramasEmbalagem,
        disponivel: i.disponivel,
        origem: i.origem,
      );

  Map<String, dynamic> toBody() => {
        'nome': nome.trim(),
        'caracteristica': caracteristica.trim(),
        'marca': marca.trim(),
        'fornecedor': fornecedor.trim(),
        'preco': preco,
        'gramas_embalagem': gramasEmbalagem,
        'disponivel': disponivel,
        'origem': origem.api,
        'preco_atualizado_em': DateTime.now().toUtc().toIso8601String(),
      };
}
