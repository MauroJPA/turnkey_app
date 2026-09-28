import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/recipe_categories/domain/categoria_receita.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  group('CategoriaReceita.fromRecord', () {
    test('lê nome, ordem e ativo', () {
      final c = CategoriaReceita.fromRecord(
        RecordModel.fromJson({
          'id': 'c1',
          'collectionName': 'categorias_receita',
          'nome': 'Massa',
          'ordem': 1,
          'ativo': true,
        }),
      );
      expect(c.nome, 'Massa');
      expect(c.ordem, 1);
      expect(c.ativo, isTrue);
    });

    test('sem ativo definido cai em false (o que vier do registo)', () {
      final c = CategoriaReceita.fromRecord(
        RecordModel.fromJson({
          'id': 'c2',
          'collectionName': 'categorias_receita',
          'nome': 'Outra',
        }),
      );
      expect(c.ativo, isFalse);
      expect(c.ordem, 0);
    });
  });

  group('CategoriaReceitaInput.toBody', () {
    test('capitaliza a primeira letra do nome', () {
      final b = CategoriaReceitaInput(
        nome: 'cobertura especial',
        ordem: 3,
      ).toBody();
      expect(b['nome'], 'Cobertura especial');
      expect(b['ordem'], 3);
      expect(b['ativo'], isTrue);
    });
  });
}
