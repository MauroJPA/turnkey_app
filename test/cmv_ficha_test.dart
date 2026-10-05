import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/pricing/domain/cost_config.dart';
import 'package:gc_turnkey/src/features/tech_sheets/domain/tech_sheet.dart';

void main() {
  ivaPorUltimo();
  // 30+15+30 = 75% em outras rubricas → CMV esperado 25%.
  const config = CostConfig(salario: 30, aluguel: 15, margemLucro: 30);

  test(
    'CMV esperado vem da configuração; real do preço de venda praticado',
    () {
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
    },
  );

  test('sem preço de venda ou sem custo não há CMV real', () {
    const semPreco = FichaTecnica(id: '1', nome: 'X', custoProduto: 2);
    expect(semPreco.cmvRealPercent(), isNull);
    const semCusto = FichaTecnica(id: '2', nome: 'Y', precoVenda: 4);
    expect(semCusto.cmvRealPercent(), isNull);
  });

  test(
    'quebra comparada: esperado pelos percentuais, real pelo preço de venda',
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
    },
  );

  test('sem preço de venda não há coluna real', () {
    final q = config.quebraComparada(1.5, 0);
    expect(q.precoReal, isNull);
    expect(q.linhas.every((l) => l.real == null && l.realPct == null), isTrue);
  });
}

/// IVA por último: a quebra faz-se sobre o preço limpo (sem IVA).
void ivaPorUltimo() {
  group('IVA por último', () {
    // rubricas sem margem = 45%; margem 30%
    const config = CostConfig(
      salario: 30,
      aluguel: 15,
      margemLucro: 30,
      ivaVendas: 20,
    );

    test('semIva / comIva são inversas', () {
      expect(config.semIva(6), closeTo(5, 1e-9));
      expect(config.comIva(5), closeTo(6, 1e-9));
    });

    test('a quebra real usa o preço sem IVA', () {
      // PVP 6,00 com 20% de IVA → 5,00 limpo
      final q = config.quebraComparada(1.5, 6);
      expect(q.precoReal, closeTo(5, 1e-9));
      expect(q.precoRealComIva, closeTo(6, 1e-9));
      final soma = q.linhas.fold<double>(0, (s, l) => s + (l.real ?? 0));
      expect(soma, closeTo(5, 1e-9)); // as linhas somam o preço SEM IVA
      final mp = q.linhas.firstWhere((l) => l.nome == 'Matéria-prima');
      expect(mp.realPct, closeTo(30, 1e-9)); // 1,5 / 5
    });

    test('o preço sugerido é sem IVA; com IVA soma-se por cima', () {
      final sem = config.precoSugerido(1.5);
      expect(config.precoSugeridoComIva(1.5), closeTo(sem * 1.2, 1e-9));
    });

    test('preço de equilíbrio: lucro zero', () {
      final eq = config.precoEquilibrio(1.5);
      expect(config.lucroSemIva(1.5, eq), closeTo(0, 1e-9));
      expect(config.lucroSemIva(1.5, eq * 1.1), greaterThan(0));
      expect(config.lucroSemIva(1.5, eq * 0.9), lessThan(0));
    });

    test('sem IVA definido nada muda', () {
      const sem = CostConfig(salario: 30, aluguel: 15, margemLucro: 30);
      expect(sem.semIva(5), 5);
      final q = sem.quebraComparada(1.5, 5);
      expect(q.precoReal, 5);
      expect(q.precoRealComIva, 5);
    });

    test('a ficha calcula CMV e margem sobre o preço sem IVA', () {
      const f = FichaTecnica(
        id: '1',
        nome: 'Boston',
        custoProduto: 1.5,
        precoVenda: 6,
      );
      expect(f.precoSemIva(20), closeTo(5, 1e-9));
      expect(f.cmvRealPercent(null, 20), closeTo(30, 1e-9));
      expect(f.margemPercentSemIva(20), closeTo(70, 1e-9));
      // sem IVA: igual ao de antes
      expect(f.cmvRealPercent(), closeTo(25, 1e-9));
    });
  });
}
