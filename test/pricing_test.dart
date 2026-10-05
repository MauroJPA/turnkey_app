import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/pricing/domain/cost_config.dart';

void main() {
  test('o CMV é o que se define; a margem é o que sobra', () {
    const c = CostConfig(cmv: 25, aluguel: 15, salario: 20);
    expect(c.cmvPercent, 25);
    expect(c.somaCustos, 35);
    expect(c.margemLucro, closeTo(40, 1e-9)); // 100 − 25 − 35
    expect(c.somaOutros, 75);
  });

  test('mexer nos custos mexe na margem, não no CMV', () {
    const antes = CostConfig(cmv: 30, salario: 10);
    final depois = antes.copyWith(salario: 20);
    expect(depois.cmvPercent, 30);
    expect(antes.margemLucro, closeTo(60, 1e-9));
    expect(depois.margemLucro, closeTo(50, 1e-9));
  });

  test('preço sugerido = custo / (CMV/100), qualquer que seja a margem', () {
    const c = CostConfig(cmv: 25, aluguel: 15);
    expect(c.precoSugerido(10), closeTo(40, 1e-9));
    expect(c.copyWith(aluguel: 50).precoSugerido(10), closeTo(40, 1e-9));
  });

  test('sem percentuais definidos, preço = custo (CMV 100%)', () {
    const c = CostConfig();
    expect(c.cmvPercent, 100);
    expect(c.precoSugerido(12.5), 12.5);
  });

  test('CMV a 0 => preço 0', () {
    const c = CostConfig(cmv: 0);
    expect(c.precoSugerido(10), 0);
  });

  test('custos que não cabem => margem negativa', () {
    const c = CostConfig(cmv: 60, salario: 30, aluguel: 20);
    expect(c.margemLucro, closeTo(-10, 1e-9));
  });

  test('quebra distribui o preço pelas rubricas + matéria-prima', () {
    const c = CostConfig(cmv: 25, aluguel: 15, salario: 20);
    final q = c.quebra(10); // preço 40
    expect(q['Matéria-prima'], 10);
    expect(q['Margem de lucro'], closeTo(16, 1e-9)); // 40% de 40
    expect(q.containsKey('Impostos'), isFalse);
    final soma = q.values.fold<double>(0, (s, v) => s + v);
    expect(soma, closeTo(40, 1e-6));
  });
}
