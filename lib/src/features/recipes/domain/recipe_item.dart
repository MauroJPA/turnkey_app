import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'recipe_item.freezed.dart';

/// Linha de uma receita: um ingrediente OU uma sub-receita, com quantidade.
///
/// [nomeResolvido] e [custoPorGramaResolvido] vêm do `expand` do PocketBase
/// (o custo definitivo é recalculado pelo hook do servidor; aqui é só para
/// pré-visualização imediata).
@freezed
class ItemReceita with _$ItemReceita {
  const factory ItemReceita({
    required String id,
    required String receitaId,
    String? ingredienteId,
    String? subReceitaId,
    @Default('') String nomeProvisorio,
    @Default(0) double quantidadeG,
    @Default('') String nomeResolvido,
    @Default(0) double custoPorGramaResolvido,
    @Default('') String ingredienteOrigem,
    String? ingredienteEspelhoId,

    /// Produto de compra fixado nesta linha (null = custo do genérico).
    String? produtoId,

    /// Unidade do ingrediente da linha (`g`, `ml` ou `un`): a quantidade está nela.
    @Default('g') String unidade,

    /// Gramas por unidade da linha (ml x densidade, un x peso da unidade; 1 para g).
    @Default(1) double fatorPeso,
  }) = _ItemReceita;

  const ItemReceita._();

  bool get pendente => ingredienteId == null && subReceitaId == null;

  /// Ingrediente que na verdade é uma receita própria (para explodir a produção).
  bool get eEspelho =>
      ingredienteOrigem == 'fabrico_proprio' &&
      (ingredienteEspelhoId?.isNotEmpty ?? false);

  double get custoLinha => custoPorGramaResolvido * quantidadeG;

  /// Peso da linha em gramas (para pesos e percentagens da receita).
  double get pesoG => quantidadeG * fatorPeso;

  String get nome => nomeResolvido.isNotEmpty
      ? nomeResolvido
      : (nomeProvisorio.isNotEmpty ? nomeProvisorio : 'Item');

  factory ItemReceita.fromRecord(RecordModel r) {
    var nome = r.getStringValue('nome_provisorio');
    var cpg = 0.0;
    var origem = '';
    var unidade = 'g';
    var fator = 1.0;
    String? espelhoId;

    final ing = r.get<List<RecordModel>>('expand.ingrediente', []);
    final sub = r.get<List<RecordModel>>('expand.sub_receita', []);
    if (ing.isNotEmpty) {
      final e = ing.first;
      nome = e.getStringValue('nome');
      final preco = e.getDoubleValue('preco');
      final g = e.getDoubleValue('gramas_embalagem');
      cpg = g > 0 ? preco / g : 0;
      origem = e.getStringValue('origem');
      final u = e.getStringValue('unidade');
      if (u == 'ml') {
        unidade = 'ml';
        final d = e.getDoubleValue('nutri_densidade');
        fator = d > 0 ? d : 1;
      } else if (u == 'un') {
        unidade = 'un';
        final g = e.getDoubleValue('gramas_unidade');
        fator = g > 0 ? g : 1;
      }
      final esp = e.getStringValue('receita_espelho');
      if (esp.isNotEmpty) espelhoId = esp;
      // produto fixado (do mesmo ingrediente): o custo é o dele
      final prod = r.get<List<RecordModel>>('expand.produto', []);
      if (prod.isNotEmpty && prod.first.getStringValue('ingrediente') == e.id) {
        final pg = prod.first.getDoubleValue('embalagem_g');
        final pp = prod.first.getDoubleValue('preco');
        if (pg > 0 && pp > 0) cpg = pp / pg;
      }
    } else if (sub.isNotEmpty) {
      final e = sub.first;
      nome = e.getStringValue('nome');
      final custo = e.getDoubleValue('custo_receita');
      final rend = e.getDoubleValue('rendimento_esperado');
      cpg = rend > 0 ? custo / rend : 0;
    }

    String? nn(String f) {
      final v = r.getStringValue(f);
      return v.isEmpty ? null : v;
    }

    return ItemReceita(
      id: r.id,
      receitaId: r.getStringValue('receita'),
      ingredienteId: nn('ingrediente'),
      subReceitaId: nn('sub_receita'),
      nomeProvisorio: r.getStringValue('nome_provisorio'),
      quantidadeG: r.getDoubleValue('quantidade_g'),
      nomeResolvido: nome,
      custoPorGramaResolvido: cpg,
      ingredienteOrigem: origem,
      ingredienteEspelhoId: espelhoId,
      produtoId: nn('produto'),
      unidade: unidade,
      fatorPeso: fator,
    );
  }
}
