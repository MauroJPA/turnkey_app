import 'package:flutter_test/flutter_test.dart';
import 'package:turnkey_app/src/features/recipes/domain/recipe_item.dart';

void main() {
  ItemReceita linha({
    String origem = '',
    String? espelhoId,
    String? ingredienteId = 'i1',
  }) =>
      ItemReceita(
        id: 'l1',
        receitaId: 'r1',
        ingredienteId: ingredienteId,
        quantidadeG: 100,
        ingredienteOrigem: origem,
        ingredienteEspelhoId: espelhoId,
      );

  test('eEspelho: fabrico próprio + espelho preenchido', () {
    expect(
      linha(origem: 'fabrico_proprio', espelhoId: 'r9').eEspelho,
      isTrue,
    );
  });

  test('eEspelho: falso para ingrediente comprado', () {
    expect(linha(origem: 'comprado', espelhoId: 'r9').eEspelho, isFalse);
  });

  test('eEspelho: falso quando não há espelho', () {
    expect(linha(origem: 'fabrico_proprio', espelhoId: null).eEspelho, isFalse);
    expect(linha(origem: 'fabrico_proprio', espelhoId: '').eEspelho, isFalse);
  });

  test('pendente continua a depender só de ingrediente/sub-receita', () {
    expect(linha(ingredienteId: 'i1').pendente, isFalse);
    expect(linha(ingredienteId: null).pendente, isTrue);
  });
}
