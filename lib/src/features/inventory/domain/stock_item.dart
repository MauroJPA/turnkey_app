import 'package:pocketbase/pocketbase.dart';

enum StockTipo { ingrediente, ficha }

/// Uma linha de inventário: junta um ingrediente ou ficha ao seu stock atual.
class StockItem {
  StockItem({
    required this.tipo,
    required this.id,
    required this.nome,
    required this.quantidade,
    required this.custoUnitario,
    this.minimo = 0,
    this.localizacao = '',
    this.inventarioId,
  });

  final StockTipo tipo;

  /// Id do ingrediente ou da ficha (não da linha de inventário).
  final String id;
  final String nome;

  /// Gramas (ingrediente) ou unidades (ficha).
  final double quantidade;

  /// € por grama (ingrediente) ou € por unidade (ficha).
  final double custoUnitario;

  final double minimo;
  final String localizacao;
  final String? inventarioId;

  String get unidade => tipo == StockTipo.ingrediente ? 'g' : 'un';

  double get valor => quantidade * custoUnitario;

  bool get stockBaixo => minimo > 0 && quantidade < minimo;

  String quantidadeLabel() {
    if (tipo == StockTipo.ficha) {
      return '${quantidade.toStringAsFixed(quantidade % 1 == 0 ? 0 : 1)} un';
    }
    return quantidade >= 1000
        ? '${(quantidade / 1000).toStringAsFixed(3)} kg'
        : '${quantidade.toStringAsFixed(quantidade < 10 ? 1 : 0)} g';
  }

  StockItem copyWith({double? quantidade, double? minimo, String? localizacao}) {
    return StockItem(
      tipo: tipo,
      id: id,
      nome: nome,
      quantidade: quantidade ?? this.quantidade,
      custoUnitario: custoUnitario,
      minimo: minimo ?? this.minimo,
      localizacao: localizacao ?? this.localizacao,
      inventarioId: inventarioId,
    );
  }
}

/// Motivo de um movimento de stock.
enum MotivoMovimento {
  compra,
  consumoProducao,
  saidaProducao,
  venda,
  ajuste,
  perda;

  static MotivoMovimento fromApi(String? v) => switch (v) {
        'compra' => MotivoMovimento.compra,
        'consumo_producao' => MotivoMovimento.consumoProducao,
        'saida_producao' => MotivoMovimento.saidaProducao,
        'venda' => MotivoMovimento.venda,
        'perda' => MotivoMovimento.perda,
        _ => MotivoMovimento.ajuste,
      };

  String get api => switch (this) {
        MotivoMovimento.compra => 'compra',
        MotivoMovimento.consumoProducao => 'consumo_producao',
        MotivoMovimento.saidaProducao => 'saida_producao',
        MotivoMovimento.venda => 'venda',
        MotivoMovimento.ajuste => 'ajuste',
        MotivoMovimento.perda => 'perda',
      };

  String get label => switch (this) {
        MotivoMovimento.compra => 'Compra',
        MotivoMovimento.consumoProducao => 'Consumo (produção)',
        MotivoMovimento.saidaProducao => 'Saída (produção)',
        MotivoMovimento.venda => 'Venda',
        MotivoMovimento.ajuste => 'Ajuste',
        MotivoMovimento.perda => 'Perda',
      };
}

class MovimentoStock {
  MovimentoStock({
    required this.delta,
    required this.motivo,
    required this.notas,
    required this.created,
  });

  final double delta;
  final MotivoMovimento motivo;
  final String notas;
  final String created;

  factory MovimentoStock.fromRecord(RecordModel r) => MovimentoStock(
        delta: r.getDoubleValue('delta'),
        motivo: MotivoMovimento.fromApi(r.getStringValue('motivo')),
        notas: r.getStringValue('notas'),
        created: r.getStringValue('created'),
      );
}
