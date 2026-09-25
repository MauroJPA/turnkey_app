import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/core/nutrition/nutrition.dart';
import 'package:gc_turnkey/src/features/ingredients/domain/produto_ingrediente.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  test('produto sem nutrição própria: valores por omissão', () {
    final p = ProdutoIngrediente.fromRecord(
      RecordModel.fromJson({'id': 'p1', 'ingrediente': 'i1', 'nome': 'X'}),
    );
    expect(p.nutriPropria, isFalse);
    expect(p.nutri.vazio, isTrue);
    expect(p.nutriBase, '100g');
    expect(p.nutriDensidade, 1);
  });

  test('produto com nutrição própria lê os campos nutri_*', () {
    final p = ProdutoIngrediente.fromRecord(
      RecordModel.fromJson({
        'id': 'p1',
        'ingrediente': 'i1',
        'nome': 'X',
        'nutri_propria': true,
        'nutri_energia_kcal': 400,
        'nutri_lipidos_g': 40,
        'nutri_base': '100ml',
        'nutri_densidade': 0.9,
        'alergenios': ['Leite'],
      }),
    );
    expect(p.nutriPropria, isTrue);
    expect(p.nutri.kcal, 400);
    expect(p.nutri.lipidos, 40);
    expect(p.nutriBase, '100ml');
    expect(p.nutriDensidade, 0.9);
    expect(p.alergenios, ['Leite']);
  });

  test('NutriProduto grava os campos nutri_* e a flag', () {
    const n = NutriProduto(
      propria: true,
      nutri: Nutrientes(kcal: 250, sal: 1.5),
      base: '100ml',
      densidade: 1.1,
    );
    final c = n.toCampos();
    expect(c['nutri_propria'], true);
    expect(c['nutri_energia_kcal'], 250);
    expect(c['nutri_sal_g'], 1.5);
    expect(c['nutri_base'], '100ml');
    expect(c['nutri_densidade'], 1.1);
  });
}
