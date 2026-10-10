import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

import 'tech_sheet.dart';

part 'tech_sheet_item.freezed.dart';

@freezed
class ItemFicha with _$ItemFicha {
  const factory ItemFicha({
    required String id,
    required String fichaId,
    required SlotFicha slot,
    String? ingredienteId,
    String? receitaId,
    String? embalagemId,
    String? kitId,

    /// Artigo de revenda do Inventário → Limpeza e insumos (bebidas…); a
    /// quantidade são unidades e o custo é o preço por unidade.
    String? consumivelId,
    @Default(0) double quantidadeG,
    @Default('') String nomeResolvido,
    @Default(0) double custoPorGramaResolvido,

    /// Unidade das quantidades de um ingrediente: `g`, `ml` ou `un` (garrafas,
    /// latas… na revenda).
    @Default('g') String unidade,
  }) = _ItemFicha;

  const ItemFicha._();

  /// Linha de kit de embalagens: a quantidade é o nº de kits, não gramas.
  bool get isKit => kitId != null;

  /// Linha de embalagem (peça avulsa ou kit): a quantidade é nº de peças/kits.
  bool get isEmbalagem =>
      slot.ehEmbalagem || embalagemId != null || kitId != null;

  double get custoLinha => custoPorGramaResolvido * quantidadeG;
  String get nome => nomeResolvido.isEmpty ? 'Item' : nomeResolvido;

  /// "120 g", "33 ml", "1 un".
  String get quantidadeTexto {
    final q = quantidadeG == quantidadeG.roundToDouble()
        ? quantidadeG.toStringAsFixed(0)
        : quantidadeG.toStringAsFixed(1);
    return '$q $unidade';
  }

  factory ItemFicha.fromRecord(RecordModel r) {
    var nome = '';
    var cpg = 0.0;
    var unidade = 'g';

    final ing = r.get<List<RecordModel>>('expand.ingrediente', []);
    final rec = r.get<List<RecordModel>>('expand.receita', []);
    final emb = r.get<List<RecordModel>>('expand.embalagem', []);
    final kit = r.get<List<RecordModel>>('expand.kit', []);
    final cons = r.get<List<RecordModel>>('expand.consumivel', []);
    if (cons.isNotEmpty) {
      final e = cons.first;
      nome = e.getStringValue('nome');
      final carac = e.getStringValue('caracteristica');
      if (carac.isNotEmpty) nome = '$nome $carac';
      cpg = e.getDoubleValue('preco');
      unidade = 'un';
    } else if (kit.isNotEmpty) {
      final e = kit.first;
      nome = e.getStringValue('nome');
      cpg = e.getDoubleValue('custo_unitario');
    } else if (emb.isNotEmpty) {
      final e = emb.first;
      nome = e.getStringValue('nome');
      final preco = e.getDoubleValue('preco_compra');
      final pecas = e.getDoubleValue('unidades_compra');
      final rende = e.getDoubleValue('rende_unidades');
      cpg = (preco / (pecas > 0 ? pecas : 1)) / (rende > 0 ? rende : 1);
    } else if (ing.isNotEmpty) {
      final e = ing.first;
      nome = e.getStringValue('nome');
      final u = e.getStringValue('unidade');
      if (u == 'ml' || u == 'un') unidade = u;
      final preco = e.getDoubleValue('preco');
      final g = e.getDoubleValue('gramas_embalagem');
      cpg = g > 0 ? preco / g : 0;
    } else if (rec.isNotEmpty) {
      final e = rec.first;
      nome = e.getStringValue('nome');
      final custo = e.getDoubleValue('custo_receita');
      final rend = e.getDoubleValue('rendimento_esperado');
      cpg = rend > 0 ? custo / rend : 0;
    }

    String? nn(String f) {
      final v = r.getStringValue(f);
      return v.isEmpty ? null : v;
    }

    return ItemFicha(
      id: r.id,
      fichaId: r.getStringValue('ficha'),
      slot: SlotFicha.fromApi(r.getStringValue('slot')),
      ingredienteId: nn('ingrediente'),
      receitaId: nn('receita'),
      embalagemId: nn('embalagem'),
      kitId: nn('kit'),
      consumivelId: nn('consumivel'),
      quantidadeG: r.getDoubleValue('quantidade_g'),
      nomeResolvido: nome,
      custoPorGramaResolvido: cpg,
      unidade: unidade,
    );
  }
}
