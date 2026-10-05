import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/finance/domain/rentabilidade.dart';
import 'package:gc_turnkey/src/features/pricing/domain/canal_venda.dart';
import 'package:gc_turnkey/src/features/pricing/domain/cost_config.dart';
import 'package:gc_turnkey/src/features/tech_sheets/domain/tech_sheet.dart';

void main() {
  // custos = 46 % do preço sem IVA, IVA 23 %
  const cfg = CostConfig(
    salario: 20,
    aluguel: 10,
    servicos: 10,
    despesasFixas: 6,
    cmv: 30,
    ivaVendas: 23,
  );

  FichaTecnica ficha(String nome, double custo, double venda, int min) =>
      FichaTecnica(
        id: nome,
        nome: nome,
        custoProduto: custo,
        precoVenda: venda,
        tempoAssaduraMin: min,
      );

  test('lucro por unidade na loja: preço sem IVA − custo − estrutura', () {
    final l = calcularRentabilidade(
      fichas: [ficha('Alba', 1.4, 6.15, 12)],
      config: cfg,
    ).single;
    expect(l.precoSemIva, closeTo(5.0, 1e-9)); // 6,15 / 1,23
    expect(l.receita, closeTo(5.0, 1e-9));
    // 5 × (1 − 0,46) − 1,4 = 1,3
    expect(l.lucroUn, closeTo(1.3, 1e-9));
    expect(l.margemPct, closeTo(26, 1e-6));
    expect(l.prejuizo, isFalse);
  });

  test('num canal com taxa de 30 % o lucro cai', () {
    const canal = CanalVenda(
      id: 'c',
      nome: 'Uber',
      taxas: [TaxaCanal(nome: 'Plataforma', percent: 30)],
    );
    final loja = calcularRentabilidade(
      fichas: [ficha('Alba', 1.4, 6.15, 12)],
      config: cfg,
    ).single;
    final uber = calcularRentabilidade(
      fichas: [ficha('Alba', 1.4, 6.15, 12)],
      config: cfg,
      canal: canal,
    ).single;
    expect(uber.receita, closeTo(3.5, 1e-9)); // 5 × 0,7
    expect(uber.lucroUn, lessThan(loja.lucroUn));
    expect(uber.lucroUn, closeTo(3.5 * 0.54 - 1.4, 1e-9)); // 0,49
  });

  test('lucro por hora de forno = lucro × unidades × 60 / minutos', () {
    final l = calcularRentabilidade(
      fichas: [ficha('Alba', 1.4, 6.15, 12)],
      config: cfg,
      capacidadeForno: 12,
    ).single;
    expect(l.lucroHora, closeTo(1.3 * 12 * 60 / 12, 1e-9)); // 78
    // sem tempo ou sem capacidade não há lucro por hora
    expect(
      calcularRentabilidade(
        fichas: [ficha('X', 1, 6, 0)],
        config: cfg,
        capacidadeForno: 12,
      ).single.lucroHora,
      isNull,
    );
    expect(
      calcularRentabilidade(
        fichas: [ficha('X', 1, 6, 10)],
        config: cfg,
      ).single.lucroHora,
      isNull,
    );
  });

  test('ordenação e produtos sem preço ou custo ficam de fora', () {
    final fs = [
      ficha('Barato', 1.0, 3.0, 10),
      ficha('Caro', 1.0, 9.0, 20),
      ficha('SemPreco', 1.0, 0, 10),
      ficha('SemCusto', 0, 5.0, 10),
    ];
    final porLucro = calcularRentabilidade(
      fichas: fs,
      config: cfg,
      capacidadeForno: 10,
    );
    expect(porLucro.map((l) => l.ficha.nome), ['Caro', 'Barato']);
    // por hora de forno o Barato (10 min) pode passar à frente do Caro (20 min)
    final porHora = calcularRentabilidade(
      fichas: fs,
      config: cfg,
      capacidadeForno: 10,
      ordem: OrdemRentabilidade.lucroHoraForno,
    );
    expect(porHora.length, 2);
    final caro = porLucro.firstWhere((l) => l.ficha.nome == 'Caro');
    final barato = porLucro.firstWhere((l) => l.ficha.nome == 'Barato');
    expect(
      porHora.first.ficha.nome,
      (caro.lucroHora! >= barato.lucroHora!) ? 'Caro' : 'Barato',
    );
  });

  test('prejuízo quando as taxas comem a margem', () {
    const canal = CanalVenda(
      id: 'c',
      nome: 'Abusivo',
      taxas: [TaxaCanal(nome: 'Comissão', percent: 60)],
    );
    final l = calcularRentabilidade(
      fichas: [ficha('Alba', 1.4, 6.15, 12)],
      config: cfg,
      canal: canal,
    ).single;
    expect(l.prejuizo, isTrue);
  });

  test('capacidade média das fornadas', () {
    expect(capacidadeMediaFornadas([12, 18, 0, 6]), closeTo(12, 1e-9));
    expect(capacidadeMediaFornadas(const []), 0);
    expect(capacidadeMediaFornadas([0, 0]), 0);
  });
}
