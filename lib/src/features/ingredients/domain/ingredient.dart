import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/formatting/capitalizar.dart';
import '../../../core/nutrition/nutrition.dart';

part 'ingredient.freezed.dart';

/// Como a informação nutricional de um ingrediente foi obtida — para
/// distinguir facilmente na lista.
enum FonteNutri {
  /// Sem valores.
  vazia,

  /// O emparelhamento automático com a INSA não teve a certeza.
  porRever,

  /// Preenchida com valores da Tabela da Composição de Alimentos (INSA).
  insa,

  /// Introduzida à mão (ou lida por IA) — sem foto do rótulo anexada.
  manual,

  /// Introduzida à mão / lida por IA, COM foto da tabela nutricional anexada.
  comFoto;

  String get label => switch (this) {
    FonteNutri.vazia => 'sem nutrição',
    FonteNutri.porRever => 'por rever (INSA)',
    FonteNutri.insa => 'da tabela INSA',
    FonteNutri.manual => 'preenchida à mão',
    FonteNutri.comFoto => 'à mão + foto do rótulo',
  };
}

enum OrigemIngrediente {
  comprado,
  fabricoProprio;

  static OrigemIngrediente fromApi(String? v) => v == 'fabrico_proprio'
      ? OrigemIngrediente.fabricoProprio
      : OrigemIngrediente.comprado;

  String get api =>
      this == OrigemIngrediente.fabricoProprio ? 'fabrico_proprio' : 'comprado';

  String get label =>
      this == OrigemIngrediente.fabricoProprio ? 'Fabrico próprio' : 'Comprado';
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

    /// Nome do ficheiro da foto da tabela nutricional (rótulo), se houver.
    @Default('') String nutriFoto,

    /// Nome curto/genérico para a lista resumida da etiqueta (opcional).
    @Default('') String nomeRotulo,

    /// Se preenchido, este "ingrediente" é na verdade um produto de fabrico próprio — um
    /// espelho da receita com este id. A nutrição vem da receita, não se
    /// preenche aqui.
    String? receitaEspelhoId,

    /// Unidade de medida das quantidades deste ingrediente: `g` (por omissão),
    /// `ml` ou `un`. Embalagem, receitas, stock e compras usam esta unidade.
    @Default('g') String unidade,

    /// Peso de cada unidade em gramas (só se [unidade] for `un`).
    @Default(0) double gramasUnidade,
  }) = _Ingrediente;

  const Ingrediente._();

  /// Preço por grama — base de todos os cálculos de custo.
  double get custoPorGrama => gramasEmbalagem > 0 ? preco / gramasEmbalagem : 0;

  /// "Farinha de trigo T55": o nome seguido da característica (se houver).
  String get nomeComCaracteristica =>
      caracteristica.trim().isEmpty ? nome : '$nome ${caracteristica.trim()}';

  /// Unidade normalizada (`g`, `ml` ou `un`).
  String get un => (unidade == 'ml' || unidade == 'un') ? unidade : 'g';

  /// É um produto de fabrico próprio (espelho de uma receita).
  bool get eProdutoProprio =>
      origem == OrigemIngrediente.fabricoProprio &&
      (receitaEspelhoId?.isNotEmpty ?? false);

  /// `true` se tem pelo menos os valores nutricionais principais.
  bool get temNutri => !nutri.vazio;

  /// Tem foto da tabela nutricional (rótulo) anexada.
  bool get temNutriFoto => nutriFoto.isNotEmpty;

  /// O emparelhamento automático com a INSA não teve a certeza — falta a
  /// pessoa escolher o alimento certo (ou preencher à mão / por foto).
  bool get precisaRevisaoInsa => nutriOrigem == 'insa_revisao';

  /// Estado da nutrição para mostrar na lista (ver [FonteNutri]).
  FonteNutri get fonteNutri {
    if (precisaRevisaoInsa) return FonteNutri.porRever;
    if (!temNutri) return FonteNutri.vazia;
    if (nutriOrigem == 'insa') return FonteNutri.insa;
    if (temNutriFoto) return FonteNutri.comFoto;
    return FonteNutri.manual;
  }

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
      nutriAtualizadoEm: nutriData.isEmpty
          ? null
          : DateTime.tryParse(nutriData),
      alergenios: lista('alergenios'),
      alergeniosTracos: lista('alergenios_tracos'),
      nutriFoto: r.getStringValue('nutri_foto'),
      nomeRotulo: r.getStringValue('nome_rotulo'),
      receitaEspelhoId: r.getStringValue('receita_espelho').isEmpty
          ? null
          : r.getStringValue('receita_espelho'),
      unidade: switch (r.getStringValue('unidade')) {
        'ml' => 'ml',
        'un' => 'un',
        _ => 'g',
      },
      gramasUnidade: r.getDoubleValue('gramas_unidade'),
    );
  }
}

/// Dados de formulário para criar/editar um ingrediente.
class IngredienteInput {
  IngredienteInput({
    required this.nome,
    this.caracteristica = '',
    this.marca = '',
    this.nomeRotulo = '',
    this.fornecedor = '',
    this.preco = 0,
    this.gramasEmbalagem = 0,
    this.disponivel = true,
    this.origem = OrigemIngrediente.comprado,
    this.unidade = 'g',
    this.gramasUnidade = 0,
  });

  final String nome;
  final String caracteristica;
  final String marca;

  /// Nome curto/genérico para a lista resumida da etiqueta (opcional).
  final String nomeRotulo;
  final String fornecedor;
  final double preco;
  final double gramasEmbalagem;
  final bool disponivel;
  final OrigemIngrediente origem;

  /// `g`, `ml` ou `un` (ver [Ingrediente.unidade]).
  final String unidade;
  final double gramasUnidade;

  factory IngredienteInput.fromModel(Ingrediente i, {String? nome}) =>
      IngredienteInput(
        nome: nome ?? i.nome,
        caracteristica: i.caracteristica,
        marca: i.marca,
        nomeRotulo: i.nomeRotulo,
        fornecedor: i.fornecedor,
        preco: i.preco,
        gramasEmbalagem: i.gramasEmbalagem,
        disponivel: i.disponivel,
        origem: i.origem,
        unidade: i.un,
        gramasUnidade: i.gramasUnidade,
      );

  Map<String, dynamic> toBody() => {
    'nome': capitalizarInicial(nome.trim()),
    'caracteristica': caracteristica.trim(),
    'marca': marca.trim(),
    'nome_rotulo': nomeRotulo.trim(),
    'fornecedor': fornecedor.trim(),
    'preco': preco,
    'gramas_embalagem': gramasEmbalagem,
    'disponivel': disponivel,
    'origem': origem.api,
    'unidade': unidade,
    'gramas_unidade': gramasUnidade,
    'preco_atualizado_em': DateTime.now().toUtc().toIso8601String(),
  };
}
