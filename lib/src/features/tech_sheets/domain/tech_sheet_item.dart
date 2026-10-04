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
    @Default(0) double quantidadeG,
    @Default('') String nomeResolvido,
    @Default(0) double custoPorGramaResolvido,
  }) = _ItemFicha;

  const ItemFicha._();

  /// Linha de kit de embalagens: a quantidade é o nº de kits, não gramas.
  bool get isKit => kitId != null;

  /// Linha de embalagem (peça avulsa ou kit): a quantidade é nº de peças/kits.
  bool get isEmbalagem =>
      slot.ehEmbalagem || embalagemId != null || kitId != null;

  double get custoLinha => custoPorGramaResolvido * quantidadeG;
  String get nome => nomeResolvido.isEmpty ? 'Item' : nomeResolvido;

  factory ItemFicha.fromRecord(RecordModel r) {
    var nome = '';
    var cpg = 0.0;

    final ing = r.get<List<RecordModel>>('expand.ingrediente', []);
    final rec = r.get<List<RecordModel>>('expand.receita', []);
    final emb = r.get<List<RecordModel>>('expand.embalagem', []);
    final kit = r.get<List<RecordModel>>('expand.kit', []);
    if (kit.isNotEmpty) {
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
      quantidadeG: r.getDoubleValue('quantidade_g'),
      nomeResolvido: nome,
      custoPorGramaResolvido: cpg,
    );
  }
}
