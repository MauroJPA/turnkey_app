import 'package:flutter_test/flutter_test.dart';
import 'package:turnkey_app/src/features/cookie_formats/domain/cookie_format.dart';

void main() {
  const recheado = FormatoCookie(
    id: 'f1',
    nome: 'Recheado',
    massaG: 120,
    recheioG: 30,
  );
  const mini = FormatoCookie(id: 'f2', nome: 'Mini', massaG: 20);

  test('unidades = round(kg*1000 / massa_g)', () {
    expect(recheado.unidades(10), 83); // 10000/120 = 83.33
    expect(recheado.unidades(12), 100);
    expect(mini.unidades(1), 50);
    expect(mini.unidades(0), 0);
  });

  test('massa_g <= 0 => 0 unidades', () {
    const mau = FormatoCookie(id: 'x', nome: 'x', massaG: 0);
    expect(mau.unidades(5), 0);
  });

  test('totalG e temRecheio', () {
    expect(recheado.totalG, 150);
    expect(recheado.temRecheio, isTrue);
    expect(mini.totalG, 20);
    expect(mini.temRecheio, isFalse);
  });

  test('recheio necessário para uma produção = unidades * recheio_g', () {
    final n = recheado.unidades(10);
    expect(n * recheado.recheioG, 2490);
  });
}
