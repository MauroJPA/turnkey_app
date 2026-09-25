import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/core/nutrition/nutrition.dart';

void main() {
  const farinha = Nutrientes(
    kcal: 348,
    lipidos: 1.2,
    saturados: 0.2,
    hidratos: 72,
    acucares: 1.5,
    fibra: 3.5,
    proteina: 10,
    sal: 0.01,
  );

  test('kj deriva de kcal (1 kcal = 4,184 kJ)', () {
    expect(const Nutrientes(kcal: 100).kj, closeTo(418.4, 0.001));
  });

  test('paraGramas escala pelos gramas (valores são por 100 g)', () {
    final n = farinha.paraGramas(250); // 2,5 x
    expect(n.kcal, closeTo(870, 0.001));
    expect(n.proteina, closeTo(25, 0.001));
  });

  test('somar contribuições e voltar a "por 100 g"', () {
    // 500 g farinha + 200 g açúcar (quase só HC)
    const acucar = Nutrientes(kcal: 400, hidratos: 100, acucares: 100);
    final total = farinha.paraGramas(500) + acucar.paraGramas(200);
    // energia total = 348*5 + 400*2 = 1740 + 800 = 2540 kcal em 700 g
    expect(total.kcal, closeTo(2540, 0.001));
    final por100 = total.por100(700);
    expect(por100.kcal, closeTo(2540 / 7, 0.001));
    expect(por100.hidratos, closeTo((72 * 5 + 100 * 2) / 7, 0.001));
  });

  test('por100 com peso 0 devolve vazio', () {
    expect(farinha.paraGramas(300).por100(0).vazio, isTrue);
  });

  test('vazio e igualdade de valor', () {
    expect(const Nutrientes().vazio, isTrue);
    expect(farinha.vazio, isFalse);
    expect(const Nutrientes(kcal: 10) == const Nutrientes(kcal: 10), isTrue);
    expect(const Nutrientes(kcal: 10) == const Nutrientes(kcal: 11), isFalse);
  });

  test('kAlergenios tem os 14 da UE', () {
    expect(kAlergenios, hasLength(14));
    expect(kAlergenios, containsAll(['Glúten', 'Leite', 'Ovos', 'Soja']));
  });

  test('NutriCache.fromJson tolera vazio e lê listas', () {
    expect(NutriCache.fromJson(null).completo, isFalse);
    expect(NutriCache.fromJson(const {}).vazio, isTrue);
    final c = NutriCache.fromJson(const {
      'por100g': {'kcal': 420, 'sal': 1.1},
      'alergenios': ['Glúten', 'Leite'],
      'completo': true,
      'sem_dados': [],
    });
    expect(c.por100g.kcal, 420);
    expect(c.alergenios, ['Glúten', 'Leite']);
    expect(c.completo, isTrue);
  });
}
