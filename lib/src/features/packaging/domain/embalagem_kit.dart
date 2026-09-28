import 'package:pocketbase/pocketbase.dart';

import '../../../core/formatting/capitalizar.dart';

/// Um kit de embalagens: conjunto nomeado de embalagens + quantidades
/// (ex.: "Take-away" = 1 saqueta + 1 caixa individual + 1 saco + 2 adesivos).
/// O custo por unidade de produto = soma de (custo/un de cada embalagem ×
/// quantidade). O servidor mantém-no em cache em `custo_unitario`.
class EmbalagemKit {
  const EmbalagemKit({
    required this.id,
    required this.nome,
    this.descricao = '',
    this.custoUnitario = 0,
    this.deletado = false,
  });

  final String id;
  final String nome;
  final String descricao;
  final double custoUnitario;
  final bool deletado;

  factory EmbalagemKit.fromRecord(RecordModel r) => EmbalagemKit(
    id: r.id,
    nome: r.getStringValue('nome'),
    descricao: r.getStringValue('descricao'),
    custoUnitario: r.getDoubleValue('custo_unitario'),
    deletado: r.getBoolValue('deletado'),
  );
}

/// Uma linha de um kit: uma embalagem e quantas peças dela entram no kit.
class EmbalagemKitItem {
  const EmbalagemKitItem({
    required this.id,
    required this.kitId,
    required this.embalagemId,
    this.quantidade = 1,
    this.nomeEmbalagem = '',
    this.custoUnidadeEmbalagem = 0,
  });

  final String id;
  final String kitId;
  final String embalagemId;
  final double quantidade;

  /// Resolvidos a partir do `expand.embalagem`.
  final String nomeEmbalagem;
  final double custoUnidadeEmbalagem;

  double get custoLinha => custoUnidadeEmbalagem * quantidade;
  String get nome => nomeEmbalagem.isEmpty ? 'Embalagem' : nomeEmbalagem;

  factory EmbalagemKitItem.fromRecord(RecordModel r) {
    var nome = '';
    var cu = 0.0;
    final emb = r.get<List<RecordModel>>('expand.embalagem', const []);
    if (emb.isNotEmpty) {
      final e = emb.first;
      nome = e.getStringValue('nome');
      final preco = e.getDoubleValue('preco_compra');
      final pecas = e.getDoubleValue('unidades_compra');
      final rende = e.getDoubleValue('rende_unidades');
      cu = (preco / (pecas > 0 ? pecas : 1)) / (rende > 0 ? rende : 1);
    }
    return EmbalagemKitItem(
      id: r.id,
      kitId: r.getStringValue('kit'),
      embalagemId: r.getStringValue('embalagem'),
      quantidade: r.getDoubleValue('quantidade'),
      nomeEmbalagem: nome,
      custoUnidadeEmbalagem: cu,
    );
  }
}

class EmbalagemKitInput {
  EmbalagemKitInput({required this.nome, this.descricao = ''});

  final String nome;
  final String descricao;

  factory EmbalagemKitInput.fromModel(EmbalagemKit k) =>
      EmbalagemKitInput(nome: k.nome, descricao: k.descricao);

  Map<String, dynamic> toBody() => {
    'nome': capitalizarInicial(nome.trim()),
    'descricao': descricao.trim(),
    'deletado': false,
  };
}
