import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/pricing/domain/canal_venda.dart';
import 'package:gc_turnkey/src/features/pricing/domain/cost_config.dart';

void main() {
  group('CanalVenda (taxas em cascata)', () {
    const loja = CanalVenda(id: '1', nome: 'Loja');
    const delivery = CanalVenda(
      id: '2',
      nome: 'Uber',
      taxas: [TaxaCanal(nome: 'Plataforma', percent: 30)],
    );
    const terceiro = CanalVenda(
      id: '3',
      nome: 'Revendedor + plataforma',
      taxas: [
        TaxaCanal(nome: 'Plataforma', percent: 30),
        TaxaCanal(nome: 'Revendedor', percent: 20),
      ],
    );

    test('a loja não tem taxas: o preço é o que recebemos', () {
      final r = loja.paraReceber(5)!;
      expect(r.precoCliente, 5);
      expect(r.receita, 5);
      expect(r.taxas, isEmpty);
    });

    test('delivery: preço X + taxa para recebermos X', () {
      final r = delivery.paraReceber(5)!;
      expect(r.precoCliente, closeTo(5 / 0.7, 1e-9));
      expect(r.receita, closeTo(5, 1e-9));
      expect(r.taxas.single.valor, closeTo(5 / 0.7 * 0.3, 1e-9));
    });

    test('terceiro: duas taxas em cascata (cada % sobre o seu nível)', () {
      final r = terceiro.paraReceber(5)!;
      // cliente paga P; plataforma tira 30% de P; revendedor 20% do que resta
      expect(r.precoCliente, closeTo(5 / (0.7 * 0.8), 1e-9));
      expect(r.receita, closeTo(5, 1e-9));
      expect(r.taxas.map((t) => t.nome), ['Plataforma', 'Revendedor']);
      final soma = r.taxas.fold<double>(0, (s, t) => s + t.valor);
      expect(soma, closeTo(r.precoCliente - 5, 1e-9));
    });

    test('ao preço da loja: o que chega a nós depois das taxas', () {
      final r = terceiro.aoPreco(5);
      expect(r.receita, closeTo(5 * 0.7 * 0.8, 1e-9));
      expect(r.totalTaxasPercent, closeTo(44, 1e-9));
    });

    test('taxa fixa por venda soma-se no seu nível', () {
      const c = CanalVenda(
        id: '4',
        nome: 'Glovo',
        taxas: [TaxaCanal(nome: 'Comissão', percent: 25, fixo: 0.5)],
      );
      final r = c.paraReceber(4)!;
      expect(r.precoCliente, closeTo((4 + 0.5) / 0.75, 1e-9));
      expect(c.aoPreco(r.precoCliente).receita, closeTo(4, 1e-9));
    });

    test('taxa de 100% ou mais não tem solução', () {
      const c = CanalVenda(
        id: '5',
        nome: 'X',
        taxas: [TaxaCanal(nome: 'Abusiva', percent: 100)],
      );
      expect(c.paraReceber(5), isNull);
    });

    test('o IVA soma-se por último, sobre o preço limpo do canal', () {
      const cfg = CostConfig(salario: 20, aluguel: 10, ivaVendas: 6);
      final r = delivery.paraReceber(5)!;
      expect(cfg.comIva(r.precoCliente), closeTo(5 / 0.7 * 1.06, 1e-9));
    });

    test('resumo e leitura do JSON das taxas', () {
      expect(loja.resumo, 'sem taxas');
      expect(terceiro.resumo, 'Plataforma 30% → Revendedor 20%');
      final l = lerTaxas([
        {'nome': 'A', 'percent': 10, 'fixo': 0.3},
        {'nome': 'B', 'percent': '5'},
      ]);
      expect(l.length, 2);
      expect(l.first.fixo, 0.3);
      expect(l.last.percent, 5);
      expect(lerTaxas(null), isEmpty);
      expect(lerTaxas('[{"nome":"C","percent":7}]').single.percent, 7);
      expect(lerTaxas('lixo'), isEmpty);
    });
  });
}
