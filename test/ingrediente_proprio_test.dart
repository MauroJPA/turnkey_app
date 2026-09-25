import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/ingredients/domain/ingredient.dart';

void main() {
  test('eProdutoProprio: fabrico próprio + receita_espelho', () {
    const espelho = Ingrediente(
      id: 'e1',
      nome: 'Boston',
      origem: OrigemIngrediente.fabricoProprio,
      receitaEspelhoId: 'rec_boston',
    );
    expect(espelho.eProdutoProprio, isTrue);
  });

  test('eProdutoProprio: falso sem receita_espelho', () {
    const feitoEmCasa = Ingrediente(
      id: 'e2',
      nome: 'Compota caseira',
      origem: OrigemIngrediente.fabricoProprio,
    );
    expect(feitoEmCasa.eProdutoProprio, isFalse);
  });

  test('eProdutoProprio: falso para ingrediente comprado', () {
    const comprado = Ingrediente(
      id: 'i1',
      nome: 'Farinha',
      origem: OrigemIngrediente.comprado,
    );
    expect(comprado.eProdutoProprio, isFalse);
  });

  test('precisaRevisaoInsa lê nutri_origem', () {
    const rever =
        Ingrediente(id: 'x', nome: 'Xarope', nutriOrigem: 'insa_revisao');
    expect(rever.precisaRevisaoInsa, isTrue);
  });
}
