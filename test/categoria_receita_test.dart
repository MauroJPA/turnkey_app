import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/recipe_categories/domain/categoria_receita.dart';

void main() {
  group('categoriasDisponiveis', () {
    test('empresa nova: só as sugeridas', () {
      expect(categoriasDisponiveis(const []), categoriasReceitaPadrao);
    });

    test('junta as que as receitas usam, sem repetir', () {
      final r = categoriasDisponiveis([
        'massa', // igual a "Massa" (ignora maiúsculas)
        'Brigadeiros',
        'Ganaches',
        '  ',
        'ganaches',
      ]);
      expect(r.take(4), categoriasReceitaPadrao);
      expect(r.skip(4), ['Brigadeiros', 'Ganaches']);
    });

    test('uma categoria sem receitas desaparece (já não está em uso)', () {
      final antes = categoriasDisponiveis(['Brigadeiros']);
      expect(antes, contains('Brigadeiros'));
      final depois = categoriasDisponiveis(const []);
      expect(depois, isNot(contains('Brigadeiros')));
    });

    test('a categoria acabada de escrever entra mesmo sem receitas', () {
      expect(
        categoriasDisponiveis(const ['Massa'], extra: const ['Mousses']),
        contains('Mousses'),
      );
    });

    test('as outras ficam por ordem alfabética', () {
      final r = categoriasDisponiveis(['Zebra', 'ábaco', 'Mousses']);
      expect(r.skip(4), ['ábaco', 'Mousses', 'Zebra']);
    });
  });

  test('CategoriaReceita usa o nome como id', () {
    const c = CategoriaReceita(nome: 'Massa');
    expect(c.id, 'Massa');
  });
}
