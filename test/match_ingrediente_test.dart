import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/consumables/domain/consumivel.dart';
import 'package:gc_turnkey/src/features/ingredients/domain/ingredient.dart';
import 'package:gc_turnkey/src/features/ingredients/domain/produto_ingrediente.dart';
import 'package:gc_turnkey/src/features/invoices/domain/match_ingrediente.dart';

Ingrediente ing(String nome, {String marca = '', String carac = ''}) =>
    Ingrediente(id: nome, nome: nome, marca: marca, caracteristica: carac);

void main() {
  final todos = [
    ing('Farinha de trigo T55'),
    ing('Manteiga', carac: 'sem sal'),
    ing('Chocolate Negro 50%', marca: 'METRO Chef'),
    ing('Açúcar Branco'),
  ];

  test('descrição de fatura casa com o ingrediente certo', () {
    expect(
      melhorMatch('FARINHA TRIGO T55 SACO 25KG', todos)?.nome,
      'Farinha de trigo T55',
    );
    expect(melhorMatch('manteiga s/ sal 1kg', todos)?.nome, 'Manteiga');
    expect(
      melhorMatch('Chocolate negro 50% metro chef 2,5kg', todos)?.nome,
      'Chocolate Negro 50%',
    );
    expect(melhorMatch('ACUCAR BRANCO CRISTAL', todos)?.nome, 'Açúcar Branco');
  });

  test('sem correspondência devolve null', () {
    expect(melhorMatch('Sacos de lixo 100L', todos), isNull);
    expect(melhorMatch('', todos), isNull);
  });

  test('a marca na descrição dá bónus de score', () {
    final semMarca = ing('Chocolate Negro 50%');
    final comMarca = ing('Chocolate Negro 50%', marca: 'METRO Chef');
    final d = 'chocolate negro 50 metro chef';
    expect(scoreMatch(d, comMarca) > scoreMatch(d, semMarca), isTrue);
  });

  group('emparelharLinha (genérico + produto)', () {
    final acucar = ing('Açúcar branco');
    final amarelo = ing('Açúcar amarelo');
    final cravo = ing('Cravinho em pó');
    final ingredientes = [acucar, amarelo, cravo];
    final sidul = ProdutoIngrediente(
      id: 'p1',
      ingredienteId: acucar.id,
      nome: 'Açúcar Sidul BCO granulado KG',
      marca: 'Sidul',
      embalagemG: 1000,
      nomesFatura: const ['acucar sidul bco granulado kg'],
    );
    final produtos = [sidul];

    test('nome de fatura já aprendido dá o produto certo', () {
      final m = emparelharLinha(
        descricao: 'Açucar Sidul BCO granulado KG',
        ingredientes: ingredientes,
        produtos: produtos,
      );
      expect(m?.ingrediente.id, acucar.id);
      expect(m?.produto?.id, 'p1');
    });

    test(
      'nome genérico da IA liga ao ingrediente mesmo com descrição estranha',
      () {
        final m = emparelharLinha(
          descricao: 'Cravinho moido margao pac 14gr',
          nomeGenerico: 'Cravinho em pó',
          marca: 'Margão',
          embalagemG: 14,
          ingredientes: ingredientes,
          produtos: produtos,
        );
        expect(m?.ingrediente.id, cravo.id);
        expect(m?.produto, isNull);
      },
    );

    test('variedades diferentes não se misturam', () {
      final m = emparelharLinha(
        descricao: 'Açucar amarelo Sidul 1kg',
        nomeGenerico: 'Açúcar amarelo',
        marca: 'Sidul',
        embalagemG: 1000,
        ingredientes: ingredientes,
        produtos: produtos,
      );
      expect(m?.ingrediente.id, amarelo.id);
      expect(m?.produto, isNull);
    });

    test('mesma marca e embalagem reutiliza o produto', () {
      final m = emparelharLinha(
        descricao: 'Açúcar branco Sidul 1 kg',
        nomeGenerico: 'Açúcar branco',
        marca: 'sidul',
        embalagemG: 1000,
        ingredientes: ingredientes,
        produtos: produtos,
      );
      expect(m?.produto?.id, 'p1');
      final outra = emparelharLinha(
        descricao: 'Açúcar branco Sidul 5 kg',
        nomeGenerico: 'Açúcar branco',
        marca: 'Sidul',
        embalagemG: 5000,
        ingredientes: ingredientes,
        produtos: produtos,
      );
      expect(outra?.ingrediente.id, acucar.id);
      expect(outra?.produto, isNull);
    });

    test('normalizarDescricao tira acentos e espaços a mais', () {
      expect(normalizarDescricao('  Açúcar   BCO  Kg '), 'acucar bco kg');
    });
  });

  group('emparelharConsumivel', () {
    const detergente = Consumivel(
      id: 'c1',
      nome: 'Detergente loiça',
      marca: 'Fairy',
      nomesFatura: ['det loica fairy original 750ml'],
    );
    const lixivia = Consumivel(id: 'c2', nome: 'Lixívia');
    const lista = [detergente, lixivia];

    test('nome de fatura aprendido', () {
      final c = emparelharConsumivel(
        descricao: 'Det. loiça Fairy Original 750ml',
        consumiveis: lista,
      );
      expect(c?.id, 'c1');
    });

    test('semelhança com o nome genérico da IA', () {
      final c = emparelharConsumivel(
        descricao: 'Detergente manual loiça Pingo Doce 1L',
        nomeGenerico: 'Detergente loiça',
        consumiveis: lista,
      );
      expect(c?.id, 'c1');
    });

    test('sem correspondência devolve null', () {
      expect(
        emparelharConsumivel(
          descricao: 'Luvas nitrilo caixa 100',
          consumiveis: lista,
        ),
        isNull,
      );
    });
  });
}
