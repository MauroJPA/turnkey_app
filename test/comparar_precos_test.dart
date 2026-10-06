import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/ingredients/domain/ingredient.dart';
import 'package:gc_turnkey/src/features/ingredients/domain/produto_ingrediente.dart';
import 'package:gc_turnkey/src/features/inventory/domain/comparar_precos.dart';

void main() {
  final hoje = DateTime(2026, 10, 6);

  ProdutoIngrediente prod(
    String id,
    String ing, {
    required double preco,
    required double emb,
    String forn = '',
    String marca = '',
    int dias = 5,
    String unidade = 'g',
  }) => ProdutoIngrediente(
    id: id,
    ingredienteId: ing,
    nome: 'Produto $id',
    marca: marca,
    fornecedor: forn,
    embalagemG: emb,
    preco: preco,
    precoAtualizadoEm: hoje.subtract(Duration(days: dias)),
    unidade: unidade,
  );

  Ingrediente ing(String id, {String unidade = 'g'}) =>
      Ingrediente(id: id, nome: 'Ingrediente $id', unidade: unidade);

  test('o mais barato ao kg ganha, mesmo com embalagens diferentes', () {
    final r = compararPrecos(
      ingredientes: [ing('a')],
      produtos: [
        prod('1', 'a', preco: 1.2, emb: 1000, forn: 'Makro', dias: 20),
        prod('2', 'a', preco: 5, emb: 5000, forn: 'Recheio', dias: 40),
      ],
      agora: hoje,
    );
    final c = r.single;
    expect(c.opcoes.first.produto.id, '2'); // 1,00 €/kg
    expect(c.maisBarata!.custo, closeTo(1.0, 1e-9));
    expect(c.emUso!.produto.id, '1'); // o mais recente (20 dias)
    expect(c.poupancaPct, closeTo(16.67, 0.01));
    expect(c.poupancaValor, closeTo(0.2, 1e-9));
    expect(c.temPoupanca, isTrue);
    expect(c.unidadePreco, 'kg');
  });

  test('se já compras o mais barato não há poupança', () {
    final c = compararPrecos(
      ingredientes: [ing('a')],
      produtos: [
        prod('1', 'a', preco: 1.0, emb: 1000, dias: 3),
        prod('2', 'a', preco: 1.5, emb: 1000, dias: 30),
      ],
      agora: hoje,
    ).single;
    expect(c.emUso!.produto.id, '1');
    expect(c.poupancaPct, 0);
    expect(c.temPoupanca, isFalse);
  });

  test('diferença pequena (<3 %) não compensa trocar', () {
    final c = compararPrecos(
      ingredientes: [ing('a')],
      produtos: [
        prod('1', 'a', preco: 1.02, emb: 1000, dias: 3),
        prod('2', 'a', preco: 1.00, emb: 1000, dias: 30),
      ],
      agora: hoje,
    ).single;
    expect(c.temPoupanca, isFalse);
  });

  test('preço antigo não entra na recomendação', () {
    final c = compararPrecos(
      ingredientes: [ing('a')],
      produtos: [
        prod('1', 'a', preco: 2.0, emb: 1000, dias: 3),
        prod('2', 'a', preco: 1.0, emb: 1000, dias: 400), // ano passado
      ],
      agora: hoje,
    ).single;
    expect(c.opcoes.first.antigo, isTrue);
    expect(c.maisBarata!.produto.id, '1');
    expect(c.temPoupanca, isFalse);
  });

  test('só ingredientes com duas ou mais opções com preço aparecem', () {
    final r = compararPrecos(
      ingredientes: [ing('a'), ing('b'), ing('c')],
      produtos: [
        prod('1', 'a', preco: 1, emb: 1000),
        prod('2', 'b', preco: 1, emb: 1000),
        prod('3', 'b', preco: 0, emb: 1000), // sem preço: ignorado
        prod('4', 'c', preco: 1, emb: 1000),
        prod('5', 'c', preco: 2, emb: 1000),
      ],
      agora: hoje,
    );
    expect(r.map((c) => c.ingrediente.id), ['c']);
  });

  test('unidades: litros e unidades inteiras', () {
    final leite = compararPrecos(
      ingredientes: [ing('l', unidade: 'ml')],
      produtos: [
        prod('1', 'l', preco: 1.2, emb: 1000, dias: 2, unidade: 'ml'),
        prod('2', 'l', preco: 5.0, emb: 6000, dias: 9, unidade: 'ml'),
      ],
      agora: hoje,
    ).single;
    expect(leite.unidadePreco, 'l');
    expect(leite.maisBarata!.custo, closeTo(0.8333, 0.001));

    final ovos = compararPrecos(
      ingredientes: [ing('o', unidade: 'un')],
      produtos: [
        prod('1', 'o', preco: 3, emb: 12, dias: 2, unidade: 'un'),
        prod('2', 'o', preco: 2.4, emb: 12, dias: 9, unidade: 'un'),
      ],
      agora: hoje,
    ).single;
    expect(ovos.unidadePreco, 'un');
    expect(ovos.maisBarata!.custo, closeTo(0.2, 1e-9));
  });

  test('ordena pela maior poupança primeiro', () {
    final r = compararPrecos(
      ingredientes: [ing('a'), ing('b')],
      produtos: [
        prod('1', 'a', preco: 1.1, emb: 1000, dias: 1),
        prod('2', 'a', preco: 1.0, emb: 1000, dias: 9),
        prod('3', 'b', preco: 2.0, emb: 1000, dias: 1),
        prod('4', 'b', preco: 1.0, emb: 1000, dias: 9),
      ],
      agora: hoje,
    );
    expect(r.map((c) => c.ingrediente.id), ['b', 'a']);
  });
}
