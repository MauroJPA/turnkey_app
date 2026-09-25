import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/ingredients/domain/nutri_ingresso.dart';

void main() {
  test('RotuloLido lê a resposta do servidor', () {
    final r = RotuloLido.fromJson({
      'nutri': {
        'energia_kcal': 380,
        'lipidos_g': 22.5,
        'saturados_g': 13,
        'hidratos_g': 40,
        'acucares_g': 30,
        'fibra_g': 2,
        'proteina_g': 5,
        'sal_g': 0.1,
      },
      'base': '100ml',
      'densidade': 1.03,
      'alergenios': ['Leite'],
      'alergenios_tracos': ['Soja'],
    });
    expect(r.nutri.kcal, 380);
    expect(r.nutri.lipidos, 22.5);
    expect(r.nutri.sal, 0.1);
    expect(r.base, '100ml');
    expect(r.densidade, 1.03);
    expect(r.alergenios, ['Leite']);
    expect(r.tracos, ['Soja']);
  });

  test('RotuloLido tolera campos em falta', () {
    final r = RotuloLido.fromJson({});
    expect(r.nutri.vazio, isTrue);
    expect(r.base, '100g');
    expect(r.densidade, 1);
  });

  test('NutriIngresso.temDados', () {
    expect(const NutriIngresso().temDados, isFalse);
    expect(const NutriIngresso(tracos: ['Soja']).temDados, isTrue);
  });
}
