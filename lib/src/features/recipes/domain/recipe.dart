import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'recipe.freezed.dart';

enum CategoriaReceita {
  massa,
  recheio,
  cobertura,
  outra;

  static CategoriaReceita fromApi(String? v) => CategoriaReceita.values
      .firstWhere((c) => c.name == v, orElse: () => CategoriaReceita.outra);

  String get api => name;

  String get label => switch (this) {
        CategoriaReceita.massa => 'Massa',
        CategoriaReceita.recheio => 'Recheio',
        CategoriaReceita.cobertura => 'Cobertura',
        CategoriaReceita.outra => 'Outra',
      };
}

@freezed
class Receita with _$Receita {
  const factory Receita({
    required String id,
    required String nome,
    required CategoriaReceita categoria,
    @Default(0) double rendimentoEsperado,
    @Default(false) bool rendimentoManual,
    @Default(0) double custoReceita,
    @Default(0) double custoPorGrama,
    @Default(false) bool publicarComoIngrediente,
    @Default(false) bool deletado,
  }) = _Receita;

  const Receita._();

  factory Receita.fromRecord(RecordModel r) => Receita(
        id: r.id,
        nome: r.getStringValue('nome'),
        categoria: CategoriaReceita.fromApi(r.getStringValue('categoria')),
        rendimentoEsperado: r.getDoubleValue('rendimento_esperado'),
        rendimentoManual: r.getBoolValue('rendimento_manual'),
        custoReceita: r.getDoubleValue('custo_receita'),
        custoPorGrama: r.getDoubleValue('custo_por_grama'),
        publicarComoIngrediente:
            r.getBoolValue('publicar_como_ingrediente'),
        deletado: r.getBoolValue('deletado'),
      );
}

/// Dados de formulário para criar/editar uma receita.
class RecipeInput {
  RecipeInput({
    required this.nome,
    required this.categoria,
    this.rendimentoEsperado = 0,
    this.rendimentoManual = false,
    this.publicarComoIngrediente = false,
  });

  final String nome;
  final CategoriaReceita categoria;
  final double rendimentoEsperado;
  final bool rendimentoManual;
  final bool publicarComoIngrediente;

  factory RecipeInput.fromModel(Receita r, {String? nome}) => RecipeInput(
        nome: nome ?? r.nome,
        categoria: r.categoria,
        rendimentoEsperado: r.rendimentoEsperado,
        rendimentoManual: r.rendimentoManual,
        publicarComoIngrediente: r.publicarComoIngrediente,
      );

  Map<String, dynamic> toBody() => {
        'nome': nome.trim(),
        'categoria': categoria.api,
        'rendimento_manual': rendimentoManual,
        if (rendimentoManual) 'rendimento_esperado': rendimentoEsperado,
        'publicar_como_ingrediente': publicarComoIngrediente,
      };
}
