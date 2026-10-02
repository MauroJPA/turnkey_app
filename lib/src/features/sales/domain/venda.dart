import 'package:pocketbase/pocketbase.dart';

/// De onde veio o registo da venda.
enum OrigemVenda {
  manual,
  csv,
  vendus;

  static OrigemVenda fromApi(String? v) => OrigemVenda.values.firstWhere(
        (o) => o.name == v,
        orElse: () => OrigemVenda.manual,
      );

  String get api => name;

  String get label => switch (this) {
        OrigemVenda.manual => 'Manual',
        OrigemVenda.csv => 'Importado (CSV)',
        OrigemVenda.vendus => 'Vendus',
      };
}

/// Canais de venda habituais — o campo é livre, estes são só sugestões.
const canaisVenda = <String>[
  'Loja física',
  'Uber Eats',
  'Glovo',
  'Bolt Food',
  'Parceria Alvalade',
  'Revenda',
  'Envio nacional',
  'Eventos',
];

/// Métodos de pagamento habituais (sugestões).
const metodosPagamento = <String>[
  'Numerário',
  'Multibanco',
  'MB Way',
  'Transferência',
  'Plataforma de entrega',
];

String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Uma venda (um dia/documento) — o total é a soma das suas [VendaItem].
class Venda {
  const Venda({
    required this.id,
    required this.data,
    this.origem = OrigemVenda.manual,
    this.total = 0,
    this.numeroDocumento = '',
    this.notas = '',
    this.canal = '',
    this.hora = '',
    this.metodoPagamento = '',
  });

  final String id;
  final DateTime data;
  final OrigemVenda origem;
  final double total;
  final String numeroDocumento;
  final String notas;

  /// Canal de venda (loja física, plataforma de entrega, revenda…); vazio =
  /// não indicado.
  final String canal;

  /// Hora da venda (HH:MM), se se conhece.
  final String hora;
  final String metodoPagamento;

  factory Venda.fromRecord(RecordModel r) {
    final s = r.getStringValue('data');
    return Venda(
      id: r.id,
      data: DateTime.tryParse(s) ?? DateTime.now(),
      origem: OrigemVenda.fromApi(r.getStringValue('origem')),
      total: r.getDoubleValue('total'),
      numeroDocumento: r.getStringValue('numero_documento'),
      notas: r.getStringValue('notas'),
      canal: r.getStringValue('canal'),
      hora: r.getStringValue('hora'),
      metodoPagamento: r.getStringValue('metodo_pagamento'),
    );
  }
}

/// Uma linha de venda — opcionalmente ligada a uma ficha técnica (produto
/// de fabrico próprio); sem correspondência fica só com [descricao] (texto livre).
class VendaItem {
  const VendaItem({
    required this.id,
    required this.vendaId,
    this.fichaId,
    this.descricao = '',
    this.quantidade = 0,
    this.precoUnitario = 0,
    this.totalLinha = 0,
    this.custoUnitarioSnapshot = 0,
    this.valorSemIva,
    this.ivaPercent,
    this.desconto,
  });

  final String id;
  final String vendaId;
  final String? fichaId;
  final String descricao;
  final double quantidade;
  final double precoUnitario;
  final double totalLinha;
  final double custoUnitarioSnapshot;

  /// Valor da linha sem IVA, taxa de IVA e desconto — só quando se conhecem
  /// (vendas do Vendus mais recentes); `null` = não indicado.
  final double? valorSemIva;
  final double? ivaPercent;
  final double? desconto;

  bool get temFicha => fichaId != null && fichaId!.isNotEmpty;

  factory VendaItem.fromRecord(RecordModel r) {
    final fichaId = r.getStringValue('ficha');
    return VendaItem(
      id: r.id,
      vendaId: r.getStringValue('venda'),
      fichaId: fichaId.isEmpty ? null : fichaId,
      descricao: r.getStringValue('descricao'),
      quantidade: r.getDoubleValue('quantidade'),
      precoUnitario: r.getDoubleValue('preco_unitario'),
      totalLinha: r.getDoubleValue('total_linha'),
      custoUnitarioSnapshot: r.getDoubleValue('custo_unitario_snapshot'),
      valorSemIva: _positivo(r.getDoubleValue('valor_sem_iva')),
      ivaPercent: _positivo(r.getDoubleValue('iva_percent')),
      desconto: _positivo(r.getDoubleValue('desconto')),
    );
  }
}

/// O servidor devolve 0 para um número nunca preenchido: trata-o como "não
/// indicado".
double? _positivo(double v) => v > 0 ? v : null;

/// Uma linha a criar (formulário manual ou importação CSV) — ainda sem id.
class VendaItemInput {
  VendaItemInput({
    this.fichaId,
    this.descricao = '',
    required this.quantidade,
    required this.precoUnitario,
    this.custoUnitarioSnapshot = 0,
  });

  final String? fichaId;
  final String descricao;
  final double quantidade;
  final double precoUnitario;
  final double custoUnitarioSnapshot;

  double get totalLinha => quantidade * precoUnitario;
}
