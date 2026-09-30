import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/ingredients/domain/ingredient.dart';
import 'package:gc_turnkey/src/features/recipes/domain/auto_link_pendentes.dart';
import 'package:gc_turnkey/src/features/recipes/domain/recipe_item.dart';

Ingrediente ing(String nome, {String carac = ''}) =>
    Ingrediente(id: nome, nome: nome, caracteristica: carac);

ItemReceita pendente(String id, String nomeProvisorio) =>
    ItemReceita(id: id, receitaId: 'r1', nomeProvisorio: nomeProvisorio);

void main() {
  final ingredientes = [
    ing('Farinha de trigo T55'),
    ing('Manteiga'),
    ing('Café em grão', carac: 'gold'),
    ing('Café em grão', carac: 'bio'),
  ];

  test('nome exatamente igual liga sem revisão', () {
    final r = sugerirLigacoes([pendente('1', 'Manteiga')], ingredientes);
    expect(r.single.temExato, isTrue);
    expect(r.single.exato?.nome, 'Manteiga');
  });

  test('nome + característica exatamente igual liga sem revisão', () {
    final r = sugerirLigacoes(
      [pendente('1', 'Café em grão gold')],
      ingredientes,
    );
    expect(r.single.temExato, isTrue);
    expect(r.single.exato?.caracteristica, 'gold');
  });

  test('nome só parecido (não exato) fica como sugestão a rever', () {
    final r = sugerirLigacoes(
      [pendente('1', 'FARINHA TRIGO T55 25KG')],
      ingredientes,
    );
    expect(r.single.temExato, isFalse);
    expect(r.single.sugestao?.nome, 'Farinha de trigo T55');
  });

  test('sem nenhuma correspondência não tem exato nem sugestão', () {
    final r = sugerirLigacoes(
      [pendente('1', 'Sacos de lixo 100L')],
      ingredientes,
    );
    expect(r.single.temExato, isFalse);
    expect(r.single.sugestao, isNull);
  });

  test('nome vazio (linha sem nome_provisorio) não tem exato nem sugestão', () {
    final r = sugerirLigacoes([pendente('1', '')], ingredientes);
    expect(r.single.temExato, isFalse);
    expect(r.single.sugestao, isNull);
  });
}
