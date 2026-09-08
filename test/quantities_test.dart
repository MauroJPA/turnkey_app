import 'package:flutter_test/flutter_test.dart';
import 'package:turnkey_app/src/core/formatting/quantities.dart';

void main() {
  test('gramasParaTexto: < 1000 g em gramas inteiras', () {
    expect(gramasParaTexto(0), '0 g');
    expect(gramasParaTexto(1), '1 g');
    expect(gramasParaTexto(999.4), '999 g');
    expect(gramasParaTexto(800), '800 g');
  });

  test('gramasParaTexto: >= 1000 g em kg, vírgula decimal, sem zeros à direita',
      () {
    expect(gramasParaTexto(1000), '1 kg');
    expect(gramasParaTexto(1200), '1,2 kg');
    expect(gramasParaTexto(1500), '1,5 kg');
    expect(gramasParaTexto(1594.2), '1,594 kg');
    expect(gramasParaTexto(2500), '2,5 kg');
    expect(gramasParaTexto(10000), '10 kg');
  });
}
