import 'package:flutter_test/flutter_test.dart';
import 'package:turnkey_app/src/features/orders/domain/encomenda.dart';

void main() {
  group('EstadoEncomenda', () {
    test('fromApi tolerante, cai em nova', () {
      expect(EstadoEncomenda.fromApi('em_producao'), EstadoEncomenda.emProducao);
      expect(EstadoEncomenda.fromApi('pronta'), EstadoEncomenda.pronta);
      expect(EstadoEncomenda.fromApi('entregue'), EstadoEncomenda.entregue);
      expect(EstadoEncomenda.fromApi('cancelada'), EstadoEncomenda.cancelada);
      expect(EstadoEncomenda.fromApi('lixo'), EstadoEncomenda.nova);
      expect(EstadoEncomenda.fromApi(null), EstadoEncomenda.nova);
    });

    test('ativa é falso só para entregue/cancelada', () {
      expect(EstadoEncomenda.nova.ativa, isTrue);
      expect(EstadoEncomenda.emProducao.ativa, isTrue);
      expect(EstadoEncomenda.pronta.ativa, isTrue);
      expect(EstadoEncomenda.entregue.ativa, isFalse);
      expect(EstadoEncomenda.cancelada.ativa, isFalse);
    });

    test('proximo segue nova → em produção → pronta → entregue → null', () {
      expect(EstadoEncomenda.nova.proximo, EstadoEncomenda.emProducao);
      expect(EstadoEncomenda.emProducao.proximo, EstadoEncomenda.pronta);
      expect(EstadoEncomenda.pronta.proximo, EstadoEncomenda.entregue);
      expect(EstadoEncomenda.entregue.proximo, isNull);
      expect(EstadoEncomenda.cancelada.proximo, isNull);
    });
  });

  group('Encomenda.estadoPagamento', () {
    Encomenda comValores({double valorTotal = 0, double valorPago = 0}) =>
        Encomenda(
          id: '1',
          clienteNome: 'Ana',
          dataHora: DateTime(2026, 9, 14),
          valorTotal: valorTotal,
          valorPago: valorPago,
        );

    test('semValor quando valorTotal não foi informado (0)', () {
      final e = comValores();
      expect(e.temValor, isFalse);
      expect(e.estadoPagamento, EstadoPagamento.semValor);
    });

    test('porPagar quando nada foi pago ainda', () {
      final e = comValores(valorTotal: 50);
      expect(e.estadoPagamento, EstadoPagamento.porPagar);
      expect(e.valorEmFalta, 50);
    });

    test('parcial quando pagou menos do que o total', () {
      final e = comValores(valorTotal: 50, valorPago: 20);
      expect(e.estadoPagamento, EstadoPagamento.parcial);
      expect(e.valorEmFalta, 30);
    });

    test('pago quando pagou tudo (ou mais)', () {
      final e = comValores(valorTotal: 50, valorPago: 50);
      expect(e.estadoPagamento, EstadoPagamento.pago);
      expect(e.valorEmFalta, 0);
    });

    test('valorEmFalta nunca fica negativo se pagar a mais', () {
      final e = comValores(valorTotal: 50, valorPago: 70);
      expect(e.valorEmFalta, 0);
    });
  });

  group('Encomenda.horasAte', () {
    test('positivo quando a encomenda é no futuro', () {
      final agora = DateTime(2026, 9, 14, 10, 0);
      final e = Encomenda(
        id: '1',
        clienteNome: 'Ana',
        dataHora: DateTime(2026, 9, 14, 14, 0),
      );
      expect(e.horasAte(agora), closeTo(4, 0.01));
    });

    test('negativo quando já passou', () {
      final agora = DateTime(2026, 9, 14, 16, 0);
      final e = Encomenda(
        id: '1',
        clienteNome: 'Ana',
        dataHora: DateTime(2026, 9, 14, 14, 0),
      );
      expect(e.horasAte(agora), closeTo(-2, 0.01));
    });
  });
}
