import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/finance/domain/numeros_magicos.dart';
import 'package:gc_turnkey/src/features/finance/domain/periodo.dart';
import 'package:gc_turnkey/src/features/inventory/domain/compra_registada.dart';
import 'package:gc_turnkey/src/features/sales/domain/venda.dart';

void main() {
  group('Periodo.diaDe', () {
    final hoje = DateTime(2026, 10, 4); // domingo

    test('rótulos: hoje, ontem e o dia da semana', () {
      expect(Periodo.diaDe(hoje, hoje: hoje).label, 'Hoje');
      expect(Periodo.diaDe(DateTime(2026, 10, 3), hoje: hoje).label, 'Ontem');
      expect(
        Periodo.diaDe(DateTime(2026, 10, 1), hoje: hoje).label,
        'Quinta-feira',
      );
    });

    test('é um único dia e navega dia a dia', () {
      final p = Periodo.diaDe(DateTime(2026, 10, 1, 15, 30), hoje: hoje);
      expect(p.desde, DateTime(2026, 10, 1));
      expect(p.ate, DateTime(2026, 10, 1));
      expect(p.dias, 1);
      expect(p.tipo, TipoPeriodo.dia);
      expect(p.anterior.desde, DateTime(2026, 9, 30));
      expect(p.seguinte.desde, DateTime(2026, 10, 2));
      expect(p.intervaloTexto, '01/10/2026');
    });

    test('um dia pesa 1/30,44 de um mês', () {
      expect(
        Periodo.diaDe(DateTime(2026, 10, 1)).fatorProrateioMensal,
        closeTo(1 / 30.44, 1e-9),
      );
    });
  });

  group('NumerosMagicos num dia', () {
    NumerosMagicos nm(Periodo p, {double vendido = 0}) => NumerosMagicos(
      periodo: p,
      custosFixosMensal: 1300,
      custosVariaveisMensal: 0,
      depreciacaoMensal: 0,
      impostoPercent: 20,
      cmvPercent: 30,
      receitaPeriodo: vendido,
    );

    test('a venda mínima do dia é a mensal ÷ 26 dias de trabalho', () {
      final n = nm(Periodo.diaDe(DateTime(2026, 10, 1)), vendido: 40);
      // mínimo mensal = 1300 / 0,5 = 2600 → por dia = 100
      expect(n.vendaMinimaDiaria, closeTo(100, 1e-9));
      expect(n.vendaMinimaDoPeriodo, closeTo(100, 1e-9));
      expect(n.faltaParaMinimo, closeTo(60, 1e-9));
    });

    test('numa semana continua a proporção de dias do mês', () {
      final n = nm(Periodo.semanaDe(DateTime(2026, 10, 1)));
      expect(n.vendaMinimaDoPeriodo, closeTo(2600 * 7 / 30.44, 1e-6));
    });

    test('vendidoPorDia soma as vendas de cada dia', () {
      final m = vendidoPorDia([
        Venda(id: 'a', data: DateTime(2026, 10, 1, 9), total: 10),
        Venda(id: 'b', data: DateTime(2026, 10, 1, 18), total: 5),
        Venda(id: 'c', data: DateTime(2026, 10, 2), total: 7),
      ]);
      expect(m[DateTime(2026, 10, 1)], 15);
      expect(m[DateTime(2026, 10, 2)], 7);
      expect(m, hasLength(2));
    });
  });

  group('compras registadas', () {
    CompraRegistada c(
      String nome,
      double q,
      DateTime d, {
      String forn = '',
      double? custo,
      String un = 'g',
    }) => CompraRegistada(
      data: d,
      nome: nome,
      quantidade: q,
      unidade: un,
      fornecedor: forn,
      custoEstimado: custo,
    );
    final compras = [
      c('Farinha', 10000, DateTime(2026, 10, 1), forn: 'Makro', custo: 6),
      c('Manteiga', 2000, DateTime(2026, 10, 1), forn: 'Makro', custo: 15),
      c('Ovos', 30, DateTime(2026, 10, 3), forn: 'Mercado', custo: 8, un: 'un'),
      c('Saco', 100, DateTime(2026, 10, 3), un: 'un'),
    ];

    test('por dia: do mais recente, com o total de cada dia', () {
      final g = agruparCompras(compras, AgruparCompras.dia);
      expect(g.map((x) => x.titulo), ['03/10/2026', '01/10/2026']);
      expect(g.first.itens, hasLength(2));
      expect(g.first.custoEstimado, 8);
      expect(g.last.custoEstimado, 21);
    });

    test('por fornecedor: do que mais custou, sem fornecedor à parte', () {
      final g = agruparCompras(compras, AgruparCompras.fornecedor);
      expect(g.first.titulo, 'Makro');
      expect(g.first.custoEstimado, 21);
      expect(g.map((x) => x.titulo), contains('(sem fornecedor)'));
    });

    test('por produto', () {
      final g = agruparCompras(compras, AgruparCompras.produto);
      expect(g.first.titulo, 'Manteiga');
      expect(g, hasLength(4));
    });

    test('quantidade em texto', () {
      expect(c('x', 10000, DateTime(2026)).quantidadeTexto, '10 kg');
      expect(c('x', 800, DateTime(2026)).quantidadeTexto, '800 g');
      expect(c('x', 30, DateTime(2026), un: 'un').quantidadeTexto, '30 un');
      expect(c('x', 1500, DateTime(2026), un: 'ml').quantidadeTexto, '1,5 L');
      expect(c('x', 250, DateTime(2026), un: 'ml').quantidadeTexto, '250 ml');
    });
  });
}
