import 'package:flutter_test/flutter_test.dart';
import 'package:turnkey_app/src/features/pricing/domain/cost_config.dart';
import 'package:turnkey_app/src/features/tech_sheets/domain/tech_sheet.dart';

void main() {
  // 30+15+30 = 75% em outras rubricas → CMV esperado 25%.
  const config = CostConfig(salario: 30, aluguel: 15, margemLucro: 30);

  test('CMV esperado vem da configuração; real do preço de venda praticado', () {
    expect(config.cmvPercent, 25);

    const f = FichaTecnica(
      id: '1',
      nome: 'Boston',
      custoProduto: 1.5,
      precoVenda: 5,
    );
    expect(f.cmvRealPercent(), closeTo(30, 1e-9));
    // usa o custo recalculado quando fornecido
    expect(f.cmvRealPercent(1.0), closeTo(20, 1e-9));
  });

  test('sem preço de venda ou sem custo não há CMV real', () {
    const semPreco = FichaTecnica(id: '1', nome: 'X', custoProduto: 2);
    expect(semPreco.cmvRealPercent(), isNull);
    const semCusto = FichaTecnica(id: '2', nome: 'Y', precoVenda: 4);
    expect(semCusto.cmvRealPercent(), isNull);
  });

  test('quebra comparada: esperado pelos percentuais, real pelo preço de venda',
      () {
    final q = config.quebraComparada(1.5, 5); // esperado 6,00; real 5,00
    expect(q.precoEsperado, closeTo(6, 1e-9));
    expect(q.precoReal, 5);

    final mp = q.linhas.firstWhere((l) => l.nome == 'Matéria-prima');
    expect(mp.esperado, 1.5);
    expect(mp.esperadoPct, 25);
    expect(mp.real, 1.5);
    expect(mp.realPct, closeTo(30, 1e-9));

    final salario = q.linhas.firstWhere((l) => l.nome == 'Salário');
    expect(salario.esperado, closeTo(1.8, 1e-9)); // 30% de 6
    expect(salario.real, closeTo(1.5, 1e-9)); // 30% de 5

    // margem real = o que sobra: 5 − 1,5 − (30%+15%)·5 = 1,25
    final margem = q.linhas.firstWhere((l) => l.nome == 'Margem de lucro');
    expect(margem.esperado, closeTo(1.8, 1e-9));
    expect(margem.real, closeTo(1.25, 1e-9));
    expect(margem.realPct, closeTo(25, 1e-9));

    // as linhas reais somam o preço de venda
    final soma = q.linhas.fold<double>(0, (s, l) => s + (l.real ?? 0));
    expect(soma, closeTo(5, 1e-9));
  });

  test('sem preço de venda não há coluna real', () {
    final q = config.quebraComparada(1.5, 0);
    expect(q.precoReal, isNull);
    expect(q.linhas.every((l) => l.real == null && l.realPct == null), isTrue);
  });
}
