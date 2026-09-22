import 'package:pocketbase/pocketbase.dart';

/// Estado de uma encomenda, do pedido à entrega.
enum EstadoEncomenda {
  nova,
  emProducao,
  pronta,
  entregue,
  cancelada;

  static EstadoEncomenda fromApi(String? v) => switch (v) {
        'em_producao' => EstadoEncomenda.emProducao,
        'pronta' => EstadoEncomenda.pronta,
        'entregue' => EstadoEncomenda.entregue,
        'cancelada' => EstadoEncomenda.cancelada,
        _ => EstadoEncomenda.nova,
      };

  String get api => switch (this) {
        EstadoEncomenda.nova => 'nova',
        EstadoEncomenda.emProducao => 'em_producao',
        EstadoEncomenda.pronta => 'pronta',
        EstadoEncomenda.entregue => 'entregue',
        EstadoEncomenda.cancelada => 'cancelada',
      };

  String get label => switch (this) {
        EstadoEncomenda.nova => 'Nova',
        EstadoEncomenda.emProducao => 'Em produção',
        EstadoEncomenda.pronta => 'Pronta',
        EstadoEncomenda.entregue => 'Entregue',
        EstadoEncomenda.cancelada => 'Cancelada',
      };

  /// Se a encomenda ainda precisa de atenção da fábrica (não concluída).
  bool get ativa =>
      this != EstadoEncomenda.entregue && this != EstadoEncomenda.cancelada;

  /// Próximo estado no fluxo normal (nova → em produção → pronta →
  /// entregue), ou `null` se já é um estado final.
  EstadoEncomenda? get proximo => switch (this) {
        EstadoEncomenda.nova => EstadoEncomenda.emProducao,
        EstadoEncomenda.emProducao => EstadoEncomenda.pronta,
        EstadoEncomenda.pronta => EstadoEncomenda.entregue,
        EstadoEncomenda.entregue => null,
        EstadoEncomenda.cancelada => null,
      };
}

/// Se uma encomenda com [valorTotal] informado já está paga, por pagar, ou
/// só parcialmente — derivado de [Encomenda.valorTotal]/[Encomenda.valorPago],
/// nunca guardado (evita ficar desincronizado dos valores reais).
enum EstadoPagamento {
  semValor,
  porPagar,
  parcial,
  pago;

  String get label => switch (this) {
        EstadoPagamento.semValor => 'Sem valor definido',
        EstadoPagamento.porPagar => 'Por pagar',
        EstadoPagamento.parcial => 'Pago parcialmente',
        EstadoPagamento.pago => 'Pago',
      };
}

class Encomenda {
  const Encomenda({
    required this.id,
    required this.clienteNome,
    this.clienteTelefone = '',
    this.clienteNotas = '',
    required this.dataHora,
    this.estado = EstadoEncomenda.nova,
    this.notas = '',
    this.criadoPor = '',
    this.valorTotal = 0,
    this.valorPago = 0,
  });

  final String id;
  final String clienteNome;
  final String clienteTelefone;
  final String clienteNotas;
  final DateTime dataHora;
  final EstadoEncomenda estado;
  final String notas;
  final String criadoPor;

  /// `0` = sem valor informado (mostra "—" em vez de €0,00) — a app sugere
  /// o valor a partir do preço de venda das fichas, mas fica editável.
  final double valorTotal;
  final double valorPago;

  bool get temValor => valorTotal > 0;
  double get valorEmFalta =>
      (valorTotal - valorPago) < 0 ? 0 : (valorTotal - valorPago);

  EstadoPagamento get estadoPagamento {
    if (!temValor) return EstadoPagamento.semValor;
    if (valorPago <= 0) return EstadoPagamento.porPagar;
    if (valorPago >= valorTotal) return EstadoPagamento.pago;
    return EstadoPagamento.parcial;
  }

  /// Horas até `dataHora` (negativo se já passou).
  double horasAte(DateTime agora) =>
      dataHora.difference(agora).inMinutes / 60;

  factory Encomenda.fromRecord(RecordModel r) => Encomenda(
        id: r.id,
        clienteNome: r.getStringValue('cliente_nome'),
        clienteTelefone: r.getStringValue('cliente_telefone'),
        clienteNotas: r.getStringValue('cliente_notas'),
        dataHora: DateTime.parse(r.getStringValue('data_hora')).toLocal(),
        estado: EstadoEncomenda.fromApi(r.getStringValue('estado')),
        notas: r.getStringValue('notas'),
        criadoPor: r.getStringValue('criado_por'),
        valorTotal: r.getDoubleValue('valor_total'),
        valorPago: r.getDoubleValue('valor_pago'),
      );
}

/// Uma linha de uma encomenda (produto + quantidade).
class EncomendaItem {
  const EncomendaItem({
    required this.id,
    required this.encomendaId,
    required this.fichaId,
    this.quantidade = 0,
    this.notas = '',
  });

  final String id;
  final String encomendaId;
  final String fichaId;
  final double quantidade;
  final String notas;

  factory EncomendaItem.fromRecord(RecordModel r) => EncomendaItem(
        id: r.id,
        encomendaId: r.getStringValue('encomenda'),
        fichaId: r.getStringValue('ficha'),
        quantidade: r.getDoubleValue('quantidade'),
        notas: r.getStringValue('notas'),
      );
}

/// Uma linha a criar (ficha + quantidade), no formulário.
class EncomendaItemInput {
  EncomendaItemInput({
    required this.fichaId,
    required this.fichaNome,
    this.quantidade = 1,
    this.notas = '',
  });

  final String fichaId;

  /// Só para mostrar no formulário antes de gravar — não é guardado.
  final String fichaNome;
  final double quantidade;
  final String notas;
}

/// Dados de uma encomenda a criar/editar (formulário).
class EncomendaInput {
  EncomendaInput({
    required this.clienteNome,
    this.clienteTelefone = '',
    this.clienteNotas = '',
    required this.dataHora,
    this.notas = '',
    required this.itens,
    this.valorTotal = 0,
    this.valorPago = 0,
  });

  final String clienteNome;
  final String clienteTelefone;
  final String clienteNotas;
  final DateTime dataHora;
  final String notas;
  final List<EncomendaItemInput> itens;
  final double valorTotal;
  final double valorPago;

  Map<String, dynamic> toBody() => {
        'cliente_nome': clienteNome.trim(),
        'cliente_telefone': clienteTelefone.trim(),
        'cliente_notas': clienteNotas.trim(),
        'data_hora': dataHora.toUtc().toIso8601String(),
        'notas': notas.trim(),
        'valor_total': valorTotal,
        'valor_pago': valorPago,
      };
}
