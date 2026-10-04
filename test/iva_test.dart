import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/finance/domain/iva.dart';
import 'package:gc_turnkey/src/features/finance/domain/periodo.dart';
import 'package:gc_turnkey/src/features/invoices/domain/fatura.dart';
import 'package:gc_turnkey/src/features/sales/domain/venda.dart';

void main() {
  final v1 = Venda(id: 'v1', data: DateTime(2026, 10, 1));
  final v2 = Venda(id: 'v2', data: DateTime(2026, 10, 2));

  group('linhasDeIva', () {
    test('IVA registado vem do valor sem IVA', () {
      final l = linhasDeIva(
        vendas: [v1],
        itens: const [
          VendaItem(id: 'i', vendaId: 'v1', totalLinha: 10.6, valorSemIva: 10),
        ],
        taxaPadraoPercent: 23,
      ).single;
      expect(l.origem, OrigemIva.registado);
      expect(l.iva, closeTo(0.6, 1e-9)); // ignora a taxa por omissão
    });

    test('sem valor sem IVA, estima com a taxa por omissão', () {
      final l = linhasDeIva(
        vendas: [v1],
        itens: const [VendaItem(id: 'i', vendaId: 'v1', totalLinha: 123)],
        taxaPadraoPercent: 23,
      ).single;
      expect(l.origem, OrigemIva.estimado);
      expect(l.iva, closeTo(23, 1e-9)); // 123 - 123/1,23
    });

    test('sem taxa definida, o IVA é desconhecido', () {
      final l = linhasDeIva(
        vendas: [v1],
        itens: const [VendaItem(id: 'i', vendaId: 'v1', totalLinha: 50)],
        taxaPadraoPercent: 0,
      ).single;
      expect(l.origem, OrigemIva.desconhecido);
      expect(l.iva, 0);
    });

    test('ignora linhas sem valor ou de vendas desconhecidas', () {
      final l = linhasDeIva(
        vendas: [v1],
        itens: const [
          VendaItem(id: 'a', vendaId: 'v1', totalLinha: 0),
          VendaItem(id: 'b', vendaId: 'nao', totalLinha: 5),
        ],
        taxaPadraoPercent: 6,
      );
      expect(l, isEmpty);
    });
  });

  group('resumoDeIva', () {
    test('liquidado − dedutível = a entregar, e por dia', () {
      final linhas = linhasDeIva(
        vendas: [v1, v2],
        itens: const [
          VendaItem(id: '1', vendaId: 'v1', totalLinha: 106, valorSemIva: 100),
          VendaItem(id: '2', vendaId: 'v1', totalLinha: 53, valorSemIva: 50),
          VendaItem(id: '3', vendaId: 'v2', totalLinha: 123),
          VendaItem(id: '4', vendaId: 'v2', totalLinha: 40),
        ],
        taxaPadraoPercent: 0,
      );
      final r = resumoDeIva(linhas: linhas, ivaDedutivel: 4);
      expect(r.ivaLiquidado, closeTo(9, 1e-9)); // 6 + 3, o resto desconhecido
      expect(r.aEntregar, closeTo(5, 1e-9));
      expect(r.linhasRegistadas, 2);
      expect(r.linhasDesconhecidas, 2);
      expect(r.incompleto, isTrue);
      expect(r.vendidoComIva, 106 + 53 + 123 + 40);
      expect(r.dias, hasLength(2));
      expect(r.dias.first.dia, DateTime(2026, 10, 1));
      expect(r.dias.first.iva, closeTo(9, 1e-9));
      expect(r.dias.last.bruto, 163);
    });

    test('crédito de IVA quando as compras têm mais IVA que as vendas', () {
      final r = resumoDeIva(linhas: const [], ivaDedutivel: 12);
      expect(r.aEntregar, -12);
      expect(r.incompleto, isFalse);
    });
  });

  group('ivaDedutivelDasFaturas', () {
    Fatura f(
      String id,
      String data,
      double iva, {
      FaturaEstado estado = FaturaEstado.confirmada,
      bool apagada = false,
      FaturaTipo tipo = FaturaTipo.fatura,
    }) => Fatura(
      id: id,
      tipo: tipo,
      estado: estado,
      dataFatura: data,
      iva: iva,
      apagada: apagada,
    );

    test('soma só as confirmadas, não apagadas, de compra e no período', () {
      final p = Periodo.mesDe(DateTime(2026, 10, 10));
      final r = ivaDedutivelDasFaturas([
        f('a', '2026-10-05', 10),
        f('b', '2026-10-31', 5),
        f('c', '2026-09-30', 99), // fora
        f('d', '2026-10-06', 99, estado: FaturaEstado.analisada),
        f('e', '2026-10-07', 99, apagada: true),
        f('g', '2026-10-08', 99, tipo: FaturaTipo.listaPrecos),
      ], p);
      expect(r, 15);
    });
  });
}
