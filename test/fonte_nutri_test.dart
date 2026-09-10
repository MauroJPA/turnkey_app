import 'package:flutter_test/flutter_test.dart';
import 'package:turnkey_app/src/core/nutrition/nutrition.dart';
import 'package:turnkey_app/src/features/ingredients/domain/ingredient.dart';

const _valores = Nutrientes(kcal: 340, proteina: 11, hidratos: 72);

Ingrediente _i({
  Nutrientes nutri = const Nutrientes(),
  String origem = '',
  String foto = '',
}) =>
    Ingrediente(
      id: 'x',
      nome: 'Farinha',
      nutri: nutri,
      nutriOrigem: origem,
      nutriFoto: foto,
    );

void main() {
  test('vazia: sem valores', () {
    expect(_i().fonteNutri, FonteNutri.vazia);
  });

  test('porRever: nutri_origem = insa_revisao', () {
    expect(_i(origem: 'insa_revisao').fonteNutri, FonteNutri.porRever);
  });

  test('insa: valores + origem insa', () {
    expect(
      _i(nutri: _valores, origem: 'insa').fonteNutri,
      FonteNutri.insa,
    );
  });

  test('manual: valores à mão, sem foto', () {
    expect(
      _i(nutri: _valores, origem: 'manual').fonteNutri,
      FonteNutri.manual,
    );
    // "rotulo" sem ficheiro guardado também conta como manual
    expect(
      _i(nutri: _valores, origem: 'rotulo').fonteNutri,
      FonteNutri.manual,
    );
  });

  test('comFoto: valores + foto anexada (origem não-INSA)', () {
    expect(
      _i(nutri: _valores, origem: 'manual', foto: 'rotulo.png').fonteNutri,
      FonteNutri.comFoto,
    );
    expect(
      _i(nutri: _valores, origem: 'rotulo', foto: 'x.jpg').fonteNutri,
      FonteNutri.comFoto,
    );
  });

  test('INSA ganha à foto (valores vêm da tabela, não do rótulo)', () {
    expect(
      _i(nutri: _valores, origem: 'insa', foto: 'x.png').fonteNutri,
      FonteNutri.insa,
    );
  });

  test('temNutriFoto', () {
    expect(_i(foto: 'x.png').temNutriFoto, isTrue);
    expect(_i().temNutriFoto, isFalse);
  });
}
