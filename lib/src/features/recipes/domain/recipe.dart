import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/formatting/capitalizar.dart';
import '../../../core/nutrition/nutrition.dart';

part 'recipe.freezed.dart';

/// A categoria de uma receita (Massa, Recheio, Cobertura…) deixou de ser uma
/// lista fixa: agora é o NOME de uma `categorias_receita` da empresa
/// (gerível em Configurações → Categorias de receitas). Guarda-se aqui como
/// texto livre — apagar/renomear uma categoria nunca quebra receitas
/// antigas, só deixa de aparecer para escolher em receitas novas.
///
/// Normaliza uma categoria vinda do `meu_app_ia` (massas, brigadeiros,
/// ganaches, mousses, geleias, coberturas, …) para uma das 4 categorias
/// semeadas por omissão em cada empresa.
String categoriaReceitaDeTextoLegado(String? v) {
  final s = (v ?? '').toLowerCase();
  if (s.contains('massa')) return 'Massa';
  if (s.contains('cobertura')) return 'Cobertura';
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
  if (recheios.any(s.contains)) return 'Recheio';
  return 'Outra';
}

@freezed
class Receita with _$Receita {
  const factory Receita({
    required String id,
    required String nome,
    required String categoria,
    @Default(0) double rendimentoEsperado,
    @Default(false) bool rendimentoManual,
    @Default(0) double custoReceita,
    @Default(0) double custoPorGrama,
    @Default(false) bool publicarComoIngrediente,
    @Default(false) bool deletado,
    @Default('') String procedimento,
    @Default(<String>[]) List<String> imagens,
    @Default(0) double perdaCozeduraPct,
    @Default(<String, dynamic>{}) Map<String, dynamic> nutriRaw,
  }) = _Receita;

  const Receita._();

  /// Passos do procedimento (linhas não vazias de [procedimento]).
  List<String> get passos => procedimento
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  /// Nutrição calculada (por 100 g de mistura crua) — ver `NutriCache`.
  NutriCache get nutri => NutriCache.fromJson(nutriRaw);

  factory Receita.fromRecord(RecordModel r) {
    final rawNutri = r.data['nutri'];
    return Receita(
      id: r.id,
      nome: r.getStringValue('nome'),
      categoria: r.getStringValue('categoria'),
      rendimentoEsperado: r.getDoubleValue('rendimento_esperado'),
      rendimentoManual: r.getBoolValue('rendimento_manual'),
      custoReceita: r.getDoubleValue('custo_receita'),
      custoPorGrama: r.getDoubleValue('custo_por_grama'),
      publicarComoIngrediente: r.getBoolValue('publicar_como_ingrediente'),
      deletado: r.getBoolValue('deletado'),
      procedimento: r.getStringValue('procedimento'),
      imagens: r.getListValue<String>('imagens'),
      perdaCozeduraPct: r.getDoubleValue('perda_cozedura_pct'),
      nutriRaw: rawNutri is Map
          ? Map<String, dynamic>.from(rawNutri)
          : const <String, dynamic>{},
    );
  }
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
    this.perdaCozeduraPct = 0,
  });

  final String nome;
  final String categoria;
  final double rendimentoEsperado;
  final bool rendimentoManual;
  final bool publicarComoIngrediente;
  final String procedimento;
  final double perdaCozeduraPct;

  factory RecipeInput.fromModel(Receita r, {String? nome}) => RecipeInput(
    nome: nome ?? r.nome,
    categoria: r.categoria,
    rendimentoEsperado: r.rendimentoEsperado,
    rendimentoManual: r.rendimentoManual,
    publicarComoIngrediente: r.publicarComoIngrediente,
    procedimento: r.procedimento,
    perdaCozeduraPct: r.perdaCozeduraPct,
  );

  Map<String, dynamic> toBody() => {
    'nome': capitalizarInicial(nome.trim()),
    'categoria': categoria,
    'rendimento_manual': rendimentoManual,
    if (rendimentoManual) 'rendimento_esperado': rendimentoEsperado,
    'publicar_como_ingrediente': publicarComoIngrediente,
    'procedimento': procedimento.trim(),
    'perda_cozedura_pct': perdaCozeduraPct,
  };
}
