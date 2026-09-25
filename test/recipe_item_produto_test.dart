import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/recipes/domain/recipe_item.dart';
import 'package:pocketbase/pocketbase.dart';

RecordModel linha({
  String? produtoIngrediente = 'i1',
  bool comProduto = true,
}) => RecordModel.fromJson({
  'id': 'l1',
  'collectionName': 'itens_receita',
  'receita': 'r1',
  'ingrediente': 'i1',
  'produto': comProduto ? 'p1' : '',
  'quantidade_g': 1000,
  'expand': {
    'ingrediente': {
      'id': 'i1',
      'nome': 'Farinha',
      'preco': 5.0,
      'gramas_embalagem': 5000,
      'origem': 'comprado',
    },
    if (comProduto)
      'produto': {
        'id': 'p1',
        'ingrediente': produtoIngrediente,
        'preco': 2.0,
        'embalagem_g': 1000,
      },
  },
});

void main() {
  test('sem produto fixado: custo do ingrediente genérico', () {
    final i = ItemReceita.fromRecord(linha(comProduto: false));
    expect(i.produtoId, isNull);
    expect(i.custoPorGramaResolvido, closeTo(0.001, 1e-9));
    expect(i.custoLinha, closeTo(1.0, 1e-9));
  });

  test('com produto fixado: custo do produto', () {
    final i = ItemReceita.fromRecord(linha());
    expect(i.produtoId, 'p1');
    expect(i.custoPorGramaResolvido, closeTo(0.002, 1e-9));
    expect(i.custoLinha, closeTo(2.0, 1e-9));
  });

  test('produto de outro ingrediente é ignorado', () {
    final i = ItemReceita.fromRecord(linha(produtoIngrediente: 'outro'));
    expect(i.custoPorGramaResolvido, closeTo(0.001, 1e-9));
  });
}
