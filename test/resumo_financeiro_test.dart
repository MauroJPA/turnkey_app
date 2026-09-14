import 'package:flutter_test/flutter_test.dart';
import 'package:turnkey_app/src/features/finance/domain/periodo.dart';
import 'package:turnkey_app/src/features/finance/domain/resumo_financeiro.dart';

ResumoFinanceiro _resumo({
  double receita = 0,
  double custoProdutos = 0,
  double custosFixos = 0,
  double custosVariaveis = 0,
  double depreciacaoMensal = 0,
}) =>
    ResumoFinanceiro(
      periodo: Periodo(desde: DateTime(2026, 1, 1), ate: DateTime(2026, 1, 7), label: 'x'),
      receita: receita,
      custoProdutos: custoProdutos,
      custosFixos: custosFixos,
      custosVariaveis: custosVariaveis,
      depreciacaoMensal: depreciacaoMensal,
      numVendas: 1,
      numLinhasSemFicha: 0,
      quebra: const {},
    );

void main() {
  group('ResumoFinanceiro', () {
    test('lucroBruto = receita - custoProdutos', () {
      final r = _resumo(receita: 100, custoProdutos: 30);
      expect(r.lucroBruto, 70);
    });

    test('lucroLiquido subtrai também custos fixos e variáveis', () {
      final r = _resumo(
          receita: 100, custoProdutos: 30, custosFixos: 20, custosVariaveis: 10);
      expect(r.lucroLiquido, 40);
    });

    test('margemLiquidaPercent com receita 0 dá 0 (não divide por zero)', () {
      final r = _resumo();
      expect(r.margemLiquidaPercent, 0);
    });

    test('margemLiquidaPercent = lucro/receita * 100', () {
      final r = _resumo(receita: 200, custoProdutos: 50, custosFixos: 50);
      expect(r.margemLiquidaPercent, closeTo(50, 0.001));
    });

    test('despesasOperacionais inclui a depreciação de equipamentos', () {
      final r = _resumo(
        receita: 300,
        custosFixos: 50,
        custosVariaveis: 20,
        depreciacaoMensal: 30,
      );
      expect(r.despesasOperacionais, closeTo(100, 0.001));
    });
  });

  group('ComparacaoFinanceira', () {
    test('variação positiva quando o atual é maior', () {
      final comp = ComparacaoFinanceira(
        atual: _resumo(receita: 150, custoProdutos: 0),
        anterior: _resumo(receita: 100, custoProdutos: 0),
      );
      expect(comp.variacaoReceitaPercent, closeTo(50, 0.001));
    });

    test('sem dados no período anterior (0) devolve null, não infinito', () {
      final comp = ComparacaoFinanceira(
        atual: _resumo(receita: 150),
        anterior: _resumo(receita: 0),
      );
      expect(comp.variacaoReceitaPercent, isNull);
    });
  });
}
