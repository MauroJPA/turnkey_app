import 'package:pocketbase/pocketbase.dart';

import '../../../core/formatting/quantities.dart';

enum StockTipo { ingrediente, ficha, consumivel, livre }

/// Categorias para itens que não são de receita — o "inventário geral da loja"
/// (mesas, bancadas, facas, sabão, sacos de lixo…).
const kCategoriasMaterial = <String>[
  'Consumível',
  'Limpeza',
  'Equipamento',
  'Mobiliário',
  'Ferramenta',
  'Outro',
];

/// Uma linha de inventário: um ingrediente, uma ficha, ou um item livre
/// (qualquer coisa da empresa: sabão, sacos de lixo, uma tesoura…).
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
    this.unidadeLivre = '',
    this.categoria = '',
    this.favorito = false,
    this.usos = 0,
    this.ultimoUso = '',
    this.unidadeIng = 'g',
  });

  final StockTipo tipo;

  /// Unidade do ingrediente (`g`, `ml` ou `un`); só conta para ingredientes.
  final String unidadeIng;

  /// Id do ingrediente/ficha; para itens livres é a própria `descricao`.
  final String id;
  final String nome;

  /// Gramas (ingrediente), unidades (ficha) ou [unidadeLivre] (item livre).
  final double quantidade;

  /// € por grama (ingrediente) ou € por unidade (ficha). 0 para itens livres.
  final double custoUnitario;

  final double minimo;
  final String localizacao;
  final String? inventarioId;

  /// Unidade dos itens livres (`un`, `caixa`, …).
  final String unidadeLivre;

  /// Categoria dos itens livres (ver [kCategoriasMaterial]). Vazio nos outros.
  final String categoria;

  /// Fixado pela pessoa para aparecer na vista "Favoritos".
  final bool favorito;

  /// Nº de vezes que entrou numa produção ou lista de compras (servidor).
  final double usos;
  final String ultimoUso;

  String get unidade => switch (tipo) {
        StockTipo.ingrediente => unidadeNormalizada(unidadeIng),
        StockTipo.ficha => 'un',
        StockTipo.consumivel => 'un',
        StockTipo.livre => unidadeLivre.isEmpty ? 'un' : unidadeLivre,
      };

  double get valor => quantidade * custoUnitario;

  bool get stockBaixo => minimo > 0 && quantidade < minimo;

  String quantidadeLabel() {
    if (tipo == StockTipo.ingrediente && unidadeNormalizada(unidadeIng) != 'g') {
      return quantidadeParaTexto(quantidade, unidadeIng);
    }
    if (tipo == StockTipo.ingrediente) {
      return quantidade >= 1000
          ? '${(quantidade / 1000).toStringAsFixed(3)} kg'
          : '${quantidade.toStringAsFixed(quantidade < 10 ? 1 : 0)} g';
    }
    final n = quantidade.toStringAsFixed(quantidade % 1 == 0 ? 0 : 1);
    return '$n $unidade';
  }

  StockItem copyWith({
    double? quantidade,
    double? minimo,
    String? localizacao,
    bool? favorito,
  }) {
    return StockItem(
      tipo: tipo,
      id: id,
      nome: nome,
      quantidade: quantidade ?? this.quantidade,
      custoUnitario: custoUnitario,
      minimo: minimo ?? this.minimo,
      localizacao: localizacao ?? this.localizacao,
      inventarioId: inventarioId,
      unidadeLivre: unidadeLivre,
      categoria: categoria,
      favorito: favorito ?? this.favorito,
      usos: usos,
      ultimoUso: ultimoUso,
      unidadeIng: unidadeIng,
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
