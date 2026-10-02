import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/finance/domain/numeros_magicos.dart';
import 'package:gc_turnkey/src/features/finance/domain/periodo.dart';

Periodo _mesCheio() => Periodo(
      desde: DateTime(2026, 9, 1),
      ate: DateTime(2026, 9, 30),
      label: 'Este mês',
    );

void main() {
  group('NumerosMagicos.custosReaisMensais', () {
    test('soma fixos + variáveis + depreciação', () {
      final n = NumerosMagicos(
        periodo: _mesCheio(),
        custosFixosMensal: 1000,
        custosVariaveisMensal: 200,
        depreciacaoMensal: 203.65,
        impostoPercent: 23,
        cmvPercent: 30,
        receitaPeriodo: 0,
      );
      expect(n.custosReaisMensais, closeTo(1403.65, 0.001));
    });
  });

  group('NumerosMagicos.vendaMinimaMensal', () {
    test('custos reais / margem livre (100 - imposto - cmv)', () {
      final n = NumerosMagicos(
        periodo: _mesCheio(),
        custosFixosMensal: 1000,
        custosVariaveisMensal: 0,
        depreciacaoMensal: 0,
        impostoPercent: 20,
        cmvPercent: 30,
        receitaPeriodo: 0,
      );
      // margem livre = 50% -> mínimo = 1000 / 0.5 = 2000
      expect(n.vendaMinimaMensal, closeTo(2000, 0.001));
      expect(n.vendaMinimaDiaria, closeTo(2000 / 26, 0.001));
    });

    test('imposto+cmv >= 100% não tem solução (null)', () {
      final n = NumerosMagicos(
        periodo: _mesCheio(),
        custosFixosMensal: 1000,
        custosVariaveisMensal: 0,
        depreciacaoMensal: 0,
        impostoPercent: 60,
        cmvPercent: 45,
        receitaPeriodo: 0,
      );
      expect(n.vendaMinimaMensal, isNull);
      expect(n.vendaMinimaDiaria, isNull);
      expect(n.vendaMinimaDoPeriodo, isNull);
      expect(n.faltaParaMinimo, isNull);
    });
  });

  group('NumerosMagicos.faltaParaMinimo', () {
    test('positivo quando ainda não vendeu o suficiente', () {
      final n = NumerosMagicos(
        periodo: _mesCheio(),
        custosFixosMensal: 1000,
        custosVariaveisMensal: 0,
        depreciacaoMensal: 0,
        impostoPercent: 20,
        cmvPercent: 30,
        receitaPeriodo: 500,
      );
      // mínimo mensal = 2000; mês completo -> fatorProrateioMensal = 1
      expect(n.vendaMinimaDoPeriodo, closeTo(2000, 0.001));
      expect(n.faltaParaMinimo, closeTo(1500, 0.001));
    });

    test('negativo quando já passou o mínimo', () {
      final n = NumerosMagicos(
        periodo: _mesCheio(),
        custosFixosMensal: 1000,
        custosVariaveisMensal: 0,
        depreciacaoMensal: 0,
        impostoPercent: 20,
        cmvPercent: 30,
        receitaPeriodo: 3000,
      );
      expect(n.faltaParaMinimo, closeTo(-1000, 0.001));
    });

    test('acima do mínimo, o lucro líquido tira imposto e CMV do excedente', () {
      final n = NumerosMagicos(
        periodo: _mesCheio(),
        custosFixosMensal: 1000,
        custosVariaveisMensal: 0,
        depreciacaoMensal: 0,
        impostoPercent: 20,
        cmvPercent: 30,
        receitaPeriodo: 3000,
      );
      // mínimo 2000 -> excedente 1000; imposto 200; CMV 300; lucro 500
      expect(n.vendidoAcimaDoMinimo, closeTo(1000, 0.001));
      expect(n.impostoSobreExcedente, closeTo(200, 0.001));
      expect(n.cmvSobreExcedente, closeTo(300, 0.001));
      expect(n.lucroLiquidoPeriodo, closeTo(500, 0.001));
    });

    test('variação do vendido face ao período comparado', () {
      final n = NumerosMagicos(
        periodo: _mesCheio(),
        custosFixosMensal: 1000,
        custosVariaveisMensal: 0,
        depreciacaoMensal: 0,
        impostoPercent: 20,
        cmvPercent: 30,
        receitaPeriodo: 1500,
        periodoComparado: Periodo(
          desde: DateTime(2026, 8, 1),
          ate: DateTime(2026, 8, 31),
          label: 'x',
        ),
        receitaComparada: 1200,
      );
      expect(n.variacaoVendidoPercent, closeTo(25, 0.001));
      final sem = NumerosMagicos(
        periodo: _mesCheio(),
        custosFixosMensal: 0,
        custosVariaveisMensal: 0,
        depreciacaoMensal: 0,
        impostoPercent: 20,
        cmvPercent: 30,
        receitaPeriodo: 100,
      );
      expect(sem.variacaoVendidoPercent, isNull);
    });

    test('abaixo do mínimo não há excedente nem lucro', () {
      final n = NumerosMagicos(
        periodo: _mesCheio(),
        custosFixosMensal: 1000,
        custosVariaveisMensal: 0,
        depreciacaoMensal: 0,
        impostoPercent: 20,
        cmvPercent: 30,
        receitaPeriodo: 500,
      );
      expect(n.vendidoAcimaDoMinimo, 0);
      expect(n.lucroLiquidoPeriodo, 0);
    });
  });
}
