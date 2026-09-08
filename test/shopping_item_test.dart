import 'package:flutter_test/flutter_test.dart';
import 'package:turnkey_app/src/features/shopping/domain/shopping_item.dart';

void main() {
  test('gramasLabel: g abaixo de 1 kg, kg (vírgula, sem zeros) a partir de 1000',
      () {
    expect(ShoppingItem.gramasLabel(0), '0 g');
    expect(ShoppingItem.gramasLabel(999), '999 g');
    expect(ShoppingItem.gramasLabel(1000), '1 kg');
    expect(ShoppingItem.gramasLabel(1200), '1,2 kg');
    expect(ShoppingItem.gramasLabel(1594.2), '1,594 kg');
    expect(ShoppingItem.gramasLabel(10000), '10 kg');
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

  test('sacos = ceil(comprarG / embalagemG); sem embalagem -> null', () {
    ShoppingItem item(double comprar, double emb) => ShoppingItem(
          id: 'x',
          descricao: 'Bicarbonato',
          comprarG: comprar,
          embalagemG: emb,
        );
    expect(item(1594, 1000).sacos, 2);
    expect(item(2000, 1000).sacos, 2);
    expect(item(0, 1000).sacos, 0);
    expect(item(1594, 0).sacos, isNull);
  });

  test('quantidadeTexto: gramas para ingredientes, unidade para manuais', () {
    const ing = ShoppingItem(
        id: 'x', descricao: 'Farinha', comprarG: 2000, embalagemG: 1000);
    expect(ing.emGramas, isTrue);
    expect(ing.quantidadeTexto(), '2 kg');

    const manual = ShoppingItem(
        id: 'y', descricao: 'Sacos de lixo', comprarG: 3, unidade: 'caixa');
    expect(manual.emGramas, isFalse);
    expect(manual.manual, isTrue);
    expect(manual.quantidadeTexto(), '3 caixa');
    expect(manual.sacos, isNull);
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
