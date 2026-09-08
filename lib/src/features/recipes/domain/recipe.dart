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

  /// Normaliza uma categoria vinda do `meu_app_ia` (massas, brigadeiros,
  /// ganaches, mousses, geleias, coberturas, …) para as 4 daqui.
  static CategoriaReceita fromLegacy(String? v) {
    final s = (v ?? '').toLowerCase();
    if (s.contains('massa')) return CategoriaReceita.massa;
    if (s.contains('cobertura')) return CategoriaReceita.cobertura;
    const recheios = [
      'recheio',
      'brigadeiro',
      'ganache',
      'mousse',
      'geleia',
      'geléia',
      'compota',
      'pasta',
      'creme',
    ];
    if (recheios.any(s.contains)) return CategoriaReceita.recheio;
    return CategoriaReceita.outra;
  }

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
    @Default('') String procedimento,
    @Default(<String>[]) List<String> imagens,
  }) = _Receita;

  const Receita._();

  /// Passos do procedimento (linhas não vazias de [procedimento]).
  List<String> get passos => procedimento
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

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
        procedimento: r.getStringValue('procedimento'),
        imagens: r.getListValue<String>('imagens'),
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
    this.procedimento = '',
  });

  final String nome;
  final CategoriaReceita categoria;
  final double rendimentoEsperado;
  final bool rendimentoManual;
  final bool publicarComoIngrediente;
  final String procedimento;

  factory RecipeInput.fromModel(Receita r, {String? nome}) => RecipeInput(
        nome: nome ?? r.nome,
        categoria: r.categoria,
        rendimentoEsperado: r.rendimentoEsperado,
        rendimentoManual: r.rendimentoManual,
        publicarComoIngrediente: r.publicarComoIngrediente,
        procedimento: r.procedimento,
      );

  Map<String, dynamic> toBody() => {
        'nome': nome.trim(),
        'categoria': categoria.api,
        'rendimento_manual': rendimentoManual,
        if (rendimentoManual) 'rendimento_esperado': rendimentoEsperado,
        'publicar_como_ingrediente': publicarComoIngrediente,
        'procedimento': procedimento.trim(),
      };
}
