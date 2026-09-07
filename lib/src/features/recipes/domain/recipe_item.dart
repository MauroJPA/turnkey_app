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
  }) = _ItemReceita;

  const ItemReceita._();

  bool get pendente => ingredienteId == null && subReceitaId == null;

  double get custoLinha => custoPorGramaResolvido * quantidadeG;

  String get nome => nomeResolvido.isNotEmpty
      ? nomeResolvido
      : (nomeProvisorio.isNotEmpty ? nomeProvisorio : 'Item');

  factory ItemReceita.fromRecord(RecordModel r) {
    var nome = r.getStringValue('nome_provisorio');
    var cpg = 0.0;

    final ing = r.get<List<RecordModel>>('expand.ingrediente', []);
    final sub = r.get<List<RecordModel>>('expand.sub_receita', []);
    if (ing.isNotEmpty) {
      final e = ing.first;
      nome = e.getStringValue('nome');
      final preco = e.getDoubleValue('preco');
      final g = e.getDoubleValue('gramas_embalagem');
      cpg = g > 0 ? preco / g : 0;
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
    );
  }
}
