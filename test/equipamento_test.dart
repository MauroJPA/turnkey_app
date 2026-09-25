import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/finance/domain/equipamento.dart';

void main() {
  group('Equipamento.custoMensal', () {
    test('custo dividido pela vida útil em meses', () {
      const e = Equipamento(id: '1', nome: 'Forno', custo: 900, vidaUtilAnos: 5);
      expect(e.custoMensal, closeTo(15, 0.001));
    });

    test('vida útil 0 não divide por zero — devolve 0', () {
      const e = Equipamento(id: '1', nome: 'Forno', custo: 900, vidaUtilAnos: 0);
      expect(e.custoMensal, 0);
    });
  });

  group('EquipamentoInput.custoMensal', () {
    test('igual à do Equipamento', () {
      final input =
          EquipamentoInput(nome: 'Balcão', custo: 1500, vidaUtilAnos: 5);
      expect(input.custoMensal, closeTo(25, 0.001));
    });
  });
}
