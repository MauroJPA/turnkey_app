import 'package:flutter_test/flutter_test.dart';
import 'package:turnkey_app/src/features/production/domain/production.dart';

void main() {
  test('fator = alvo / rendimento base; custo e peso escalam', () {
    // Receita base: rende 1000 g, custa (a esta escala) 4,00 €.
    // Queremos produzir 2,5 kg -> fator 2,5.
    final node = ProductionNode(
      receitaId: 'r1',
      nome: 'Massa',
      alvoG: 2500,
      rendimentoBase: 1000,
      linhas: [
        ProductionLine(nome: 'Farinha', quantidadeG: 600 * 2.5, custo: 3 * 2.5),
        ProductionLine(nome: 'Água', quantidadeG: 400 * 2.5, custo: 1 * 2.5),
      ],
      subReceitas: const [],
    );

    expect(node.fator, 2.5);
    expect(node.pesoLinhas, 2500);
    expect(node.custoTotal, closeTo(10, 1e-9));
  });

  test('sub-receitas somam para o custo e peso do pai', () {
    final sub = ProductionNode(
      receitaId: 'r2',
      nome: 'Recheio',
      alvoG: 500,
      rendimentoBase: 250,
      linhas: [ProductionLine(nome: 'Chocolate', quantidadeG: 500, custo: 6)],
      subReceitas: const [],
    );
    final pai = ProductionNode(
      receitaId: 'r1',
      nome: 'Bolo',
      alvoG: 2000,
      rendimentoBase: 1000,
      linhas: [ProductionLine(nome: 'Ovos', quantidadeG: 300, custo: 1.2)],
      subReceitas: [sub],
    );

    expect(pai.custoTotal, closeTo(1.2 + 6, 1e-9));
    expect(pai.pesoLinhas, 300 + 500);
  });

  test('sem rendimento base não escala', () {
    final node = ProductionNode(
      receitaId: 'r1',
      nome: 'X',
      alvoG: 1000,
      rendimentoBase: 0,
      linhas: const [],
      subReceitas: const [],
    );
    expect(node.semRendimento, isTrue);
    expect(node.fator, 0);
  });
}
