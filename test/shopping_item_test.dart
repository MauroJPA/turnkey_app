import 'package:flutter_test/flutter_test.dart';
import 'package:turnkey_app/src/features/shopping/domain/shopping_item.dart';

void main() {
  test('gramasLabel: g abaixo de 1 kg, kg com 3 casas a partir de 1000', () {
    expect(ShoppingItem.gramasLabel(0), '0 g');
    expect(ShoppingItem.gramasLabel(999), '999 g');
    expect(ShoppingItem.gramasLabel(1000), '1.000 kg');
    expect(ShoppingItem.gramasLabel(1594.2), '1.594 kg');
  });

  test('grupo cai em "Sem fornecedor" quando vazio ou só espaços', () {
    ShoppingItem base(String forn) => ShoppingItem(
          id: 'x',
          descricao: 'Item',
          fornecedor: forn,
        );
    expect(base('').grupo, 'Sem fornecedor');
    expect(base('   ').grupo, 'Sem fornecedor');
    expect(base('Makro').grupo, 'Makro');
  });

  test('copyWith mantém identidade e só troca comprarG/comprado', () {
    const item = ShoppingItem(
      id: 'a1',
      ingredienteId: 'i1',
      descricao: 'Farinha',
      fornecedor: 'Makro',
      necessariaG: 2000,
      comprarG: 1500,
    );
    final mudado = item.copyWith(comprarG: 800, comprado: true);
    expect(mudado.id, 'a1');
    expect(mudado.ingredienteId, 'i1');
    expect(mudado.descricao, 'Farinha');
    expect(mudado.necessariaG, 2000);
    expect(mudado.comprarG, 800);
    expect(mudado.comprado, isTrue);
  });
}
