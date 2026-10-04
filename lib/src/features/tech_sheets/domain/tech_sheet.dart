import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../../core/formatting/capitalizar.dart';
import '../../../core/nutrition/nutrition.dart';

part 'tech_sheet.freezed.dart';

/// Papel de um item dentro de um produto final.
enum SlotFicha {
  massa,
  recheioBase,
  recheioTop,
  coberturaBase,
  coberturaTop,
  extra,
  embalagem,
  embalagemPlataforma;

  static SlotFicha fromApi(String? v) => switch (v) {
    'massa' => SlotFicha.massa,
    'recheio_base' => SlotFicha.recheioBase,
    'recheio_top' => SlotFicha.recheioTop,
    'cobertura_base' => SlotFicha.coberturaBase,
    'cobertura_top' => SlotFicha.coberturaTop,
    'embalagem' => SlotFicha.embalagem,
    'embalagem_plataforma' => SlotFicha.embalagemPlataforma,
    _ => SlotFicha.extra,
  };

  String get api => switch (this) {
    SlotFicha.massa => 'massa',
    SlotFicha.recheioBase => 'recheio_base',
    SlotFicha.recheioTop => 'recheio_top',
    SlotFicha.coberturaBase => 'cobertura_base',
    SlotFicha.coberturaTop => 'cobertura_top',
    SlotFicha.extra => 'extra',
    SlotFicha.embalagem => 'embalagem',
    SlotFicha.embalagemPlataforma => 'embalagem_plataforma',
  };

  String get label => switch (this) {
    SlotFicha.massa => 'Massa',
    SlotFicha.recheioBase => 'Recheio (base)',
    SlotFicha.recheioTop => 'Recheio (topo)',
    SlotFicha.coberturaBase => 'Cobertura (base)',
    SlotFicha.coberturaTop => 'Cobertura (topo)',
    SlotFicha.extra => 'Extra',
    SlotFicha.embalagem => 'Embalagem',
    SlotFicha.embalagemPlataforma => 'Embalagem para plataformas',
  };

  /// Blocos de embalagem (peças ou kits, não gramas).
  bool get ehEmbalagem =>
      this == SlotFicha.embalagem || this == SlotFicha.embalagemPlataforma;
}

@freezed
class FichaTecnica with _$FichaTecnica {
  const factory FichaTecnica({
    required String id,
    required String nome,
    @Default('') String categoria,
    @Default(0) double custoProduto,
    @Default(0) double pesoProduto,
    @Default(0) double precoVenda,
    @Default(false) bool deletado,
    @Default('') String formatoId,
    @Default('') String descricao,

    /// Segundo nome do produto (ex.: "Red Velvet" em "Carolina do Sul"); pode
    /// ir na etiqueta, por baixo do nome.
    @Default('') String subnome,
    @Default(0) int validadeDias,
    @Default('') String conservacao,
    @Default(<String, dynamic>{}) Map<String, dynamic> nutriRaw,

    /// Descrições de linhas de venda já ligadas manualmente a este produto
    /// (normalizadas), para reconhecer sozinho a mesma descrição em
    /// importações futuras — ver `fichaParaVenda`.
    @Default(<String>[]) List<String> nomesVenda,

    /// `false` se algum ingrediente da árvore (direto ou via massa/sub-receita)
    /// não tem preço definido — o custo calculado fica incompleto/errado.
    @Default(true) bool custoCompleto,

    /// Ingredientes (em toda a árvore) sem preço — para avisar e permitir
    /// corrigir, tal como `nutri.semDados`.
    @Default(<({String id, String nome})>[])
    List<({String id, String nome})> custoSemDados,
  }) = _FichaTecnica;

  const FichaTecnica._();

  /// Declaração nutricional calculada (por 100 g de produto acabado + por
  /// unidade) e alergénios agregados — ver `NutriCache`.
  NutriCache get nutri => NutriCache.fromJson(nutriRaw);

  bool get temPrecoVenda => precoVenda > 0;

  /// CMV real: custo da matéria-prima como % do preço de venda praticado.
  /// `null` se ainda não há preço de venda ou custo. [custo] permite usar o
  /// custo recalculado em vez do guardado.
  double? cmvRealPercent([double? custo]) {
    final c = custo ?? custoProduto;
    return temPrecoVenda && c > 0 ? c / precoVenda * 100 : null;
  }

  /// Margem de lucro sobre o preço de venda (0 se não houver preço definido).
  double get margemPercent =>
      temPrecoVenda ? (1 - custoProduto / precoVenda) * 100 : 0;

  factory FichaTecnica.fromRecord(RecordModel r) {
    final rawNutri = r.data['nutri'];
    return FichaTecnica(
      id: r.id,
      nome: r.getStringValue('nome'),
      categoria: r.getStringValue('categoria'),
      custoProduto: r.getDoubleValue('custo_produto'),
      pesoProduto: r.getDoubleValue('peso_produto'),
      precoVenda: r.getDoubleValue('preco_venda'),
      deletado: r.getBoolValue('deletado'),
      formatoId: r.getStringValue('formato'),
      descricao: r.getStringValue('descricao'),
      subnome: r.getStringValue('subnome'),
      validadeDias: r.getIntValue('validade_dias'),
      conservacao: r.getStringValue('conservacao'),
      nutriRaw: rawNutri is Map
          ? Map<String, dynamic>.from(rawNutri)
          : const <String, dynamic>{},
      nomesVenda: switch (r.data['nomes_venda']) {
        final List v => v.map((e) => '$e').toList(),
        _ => const <String>[],
      },
      custoCompleto: r.getBoolValue('custo_completo'),
      custoSemDados: _semDadosCusto(r.data['custo_sem_dados']),
    );
  }
}

List<({String id, String nome})> _semDadosCusto(Object? v) {
  if (v is! List) return const [];
  return v
      .map<({String id, String nome})>((e) {
        if (e is Map) {
          return (
            id: (e['id'] ?? '').toString(),
            nome: (e['nome'] ?? '').toString(),
          );
        }
        return (id: '', nome: '$e');
      })
      .where((x) => x.nome.isNotEmpty)
      .toList();
}

class FichaInput {
  FichaInput({
    required this.nome,
    this.categoria = '',
    this.formatoId = '',
    this.descricao = '',
    this.subnome = '',
    this.validadeDias = 0,
    this.conservacao = '',
  });

  final String nome;
  final String categoria;

  /// Formato de cookie do produto (Mini, Recheado…); vazio = sem formato.
  final String formatoId;

  /// Descrição curta (aparece na etiqueta), prazo de validade em dias a
  /// contar do fabrico (0 = não definido) e modo de conservação.
  final String descricao;

  /// Segundo nome (opcional) — ver [FichaTecnica.subnome].
  final String subnome;
  final int validadeDias;
  final String conservacao;

  Map<String, dynamic> toBody() => {
    'nome': capitalizarInicial(nome.trim()),
    'categoria': categoria.trim(),
    'formato': formatoId,
    'descricao': descricao.trim(),
    'subnome': subnome.trim(),
    'validade_dias': validadeDias,
    'conservacao': conservacao.trim(),
  };
}
