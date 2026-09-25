import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/ingredients/domain/ingredient.dart';
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
    expect(melhorMatch('FARINHA TRIGO T55 SACO 25KG', todos)?.nome,
        'Farinha de trigo T55');
    expect(melhorMatch('manteiga s/ sal 1kg', todos)?.nome, 'Manteiga');
    expect(melhorMatch('Chocolate negro 50% metro chef 2,5kg', todos)?.nome,
        'Chocolate Negro 50%');
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
}
