import 'package:flutter_test/flutter_test.dart';
import 'package:turnkey_app/src/features/recipes/application/recipes_providers.dart';
import 'package:turnkey_app/src/features/recipes/domain/recipe.dart';
import 'package:turnkey_app/src/features/recipes/domain/recipe_item.dart';

Receita _r({bool manual = false, double rendimento = 0}) => Receita(
      id: 'r1',
      nome: 'Massa',
      categoria: CategoriaReceita.massa,
      rendimentoManual: manual,
      rendimentoEsperado: rendimento,
    );

ItemReceita _i(double qtd, double cpg, {bool pendente = false}) => ItemReceita(
      id: 'i${qtd.toInt()}',
      receitaId: 'r1',
      ingredienteId: pendente ? null : 'ing',
      quantidadeG: qtd,
      custoPorGramaResolvido: cpg,
      nomeResolvido: pendente ? '' : 'X',
    );

void main() {
  test('peso e custo somam as linhas; % por linha', () {
    final d = RecipeDetail(
      receita: _r(),
      itens: [_i(400, 0.01), _i(100, 0.02)],
    );
    expect(d.pesoLinhas, 500);
    expect(d.pesoTotal, 500);
    expect(d.custoPreview, closeTo(4 + 2, 1e-9));
    expect(d.custoPorKg, closeTo((6 / 500) * 1000, 1e-9));
    expect(d.percentagem(d.itens.first), closeTo(80, 1e-9));
  });

  test('rendimento manual sobrepõe o somatório no pesoTotal', () {
    final d = RecipeDetail(
      receita: _r(manual: true, rendimento: 1000),
      itens: [_i(400, 0.01), _i(100, 0.02)],
    );
    expect(d.pesoLinhas, 500);
    expect(d.pesoTotal, 1000);
    expect(d.custoPorKg, closeTo((6 / 1000) * 1000, 1e-9));
  });

  test('deteta linhas pendentes', () {
    final d = RecipeDetail(
      receita: _r(),
      itens: [_i(100, 0), _i(50, 0, pendente: true)],
    );
    expect(d.temPendencias, isTrue);
  });
}
