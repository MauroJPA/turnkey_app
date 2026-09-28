import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/recipes/domain/receita_csv.dart';

void main() {
  test('tabela colada (tab): agrupa por receita, categoria e quantidades', () {
    const colado =
        'Massa_Normandia\tMassas\tManteiga\t191\n'
        'Massa_Normandia\tMassas\tAçucar Amarelo\t90\n'
        'Massa_Normandia\tMassas\tChocolate Negro 50% METRO Chef\t150\n'
        'Recheio_X\tRecheios\tNatas\t200,5';
    final r = parseReceitasCsv(colado);
    expect(r.erros, isEmpty);
    expect(r.receitas.length, 2);
    final m = r.receitas.first;
    expect(m.nome, 'Massa_Normandia');
    expect(m.categoria, 'Massa');
    expect(m.linhas.length, 3);
    expect(m.linhas[2].ingrediente, 'Chocolate Negro 50% METRO Chef');
    expect(m.linhas[2].quantidadeG, 150);
    expect(r.receitas[1].categoria, 'Recheio');
    expect(r.receitas[1].linhas.single.quantidadeG, 200.5);
  });

  test('CSV com ; e cabeçalho, quantidade com "g"', () {
    final r = parseReceitasCsv(
      'nome;categoria;ingrediente;quantidade\nA;Massas;Sal;4 g\nA;Massas;Ovo;64',
    );
    expect(r.erros, isEmpty);
    expect(r.receitas.single.linhas.length, 2);
    expect(r.receitas.single.linhas.first.quantidadeG, 4);
  });

  test('linhas inválidas vão para erros sem travar o resto', () {
    final r = parseReceitasCsv('A,Massas,Sal,abc\nA,Massas,Ovo,64\nB,Massas');
    expect(r.receitas.single.linhas.length, 1);
    expect(r.erros.length, 2);
  });
}
