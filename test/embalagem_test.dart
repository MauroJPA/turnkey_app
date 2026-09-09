import 'package:flutter_test/flutter_test.dart';
import 'package:turnkey_app/src/features/packaging/domain/embalagem.dart';

void main() {
  test('custoPeca = preço da compra ÷ peças; custoUnidade divide pelo rende',
      () {
    const caixa = Embalagem(
      id: 'e1',
      nome: 'Caixa 6 un',
      tipo: 'Caixa',
      precoCompra: 120, // pacote de 100 caixas
      unidadesCompra: 100,
      rendeUnidades: 6,
    );
    expect(caixa.custoPeca, closeTo(1.2, 1e-9)); // €1,20 por caixa
    expect(caixa.custoUnidade, closeTo(0.2, 1e-9)); // €0,20 por cookie
  });

  test('valores em falta assumem 1 (não dividir por zero)', () {
    const adesivo = Embalagem(
      id: 'e2',
      nome: 'Adesivo',
      precoCompra: 5,
      unidadesCompra: 0,
      rendeUnidades: 0,
    );
    expect(adesivo.custoPeca, 5);
    expect(adesivo.custoUnidade, 5);
  });

  test('toBody normaliza peças/rende <= 0 para 1', () {
    final b = EmbalagemInput(
      nome: ' Saco ',
      unidadesCompra: 0,
      rendeUnidades: -3,
    ).toBody();
    expect(b['nome'], 'Saco');
    expect(b['unidades_compra'], 1);
    expect(b['rende_unidades'], 1);
  });
}
