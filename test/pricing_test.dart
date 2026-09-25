import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/pricing/domain/cost_config.dart';

void main() {
  test('CMV = 100 - soma das outras rubricas', () {
    const c = CostConfig(margemLucro: 40, impostos: 20, aluguel: 15);
    expect(c.somaOutros, 75);
    expect(c.cmvPercent, 25);
  });

  test('preço sugerido = custo / (CMV/100)', () {
    const c = CostConfig(margemLucro: 40, impostos: 20, aluguel: 15); // CMV 25%
    expect(c.precoSugerido(10), closeTo(40, 1e-9));
  });

  test('sem percentuais definidos, preço = custo (CMV 100%)', () {
    const c = CostConfig();
    expect(c.cmvPercent, 100);
    expect(c.precoSugerido(12.5), 12.5);
  });

  test('percentuais somam >= 100 => preço 0', () {
    const c = CostConfig(margemLucro: 60, impostos: 50);
    expect(c.cmvPercent, lessThanOrEqualTo(0));
    expect(c.precoSugerido(10), 0);
  });

  test('quebra distribui o preço pelas rubricas + matéria-prima', () {
    const c = CostConfig(margemLucro: 40, impostos: 20, aluguel: 15); // CMV 25
    final q = c.quebra(10); // preço 40
    expect(q['Matéria-prima'], 10);
    expect(q['Margem de lucro'], closeTo(16, 1e-9));
    expect(q['Impostos'], closeTo(8, 1e-9));
    final soma = q.values.fold<double>(0, (s, v) => s + v);
    expect(soma, closeTo(40, 1e-6));
  });
}
