import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/sales/domain/venda.dart';
import 'package:gc_turnkey/src/features/tech_sheets/domain/tech_sheet.dart';

void main() {
  group('FichaTecnica.precoVenda / margemPercent', () {
    test('sem preço definido: temPrecoVenda falso, margem 0', () {
      const f = FichaTecnica(id: '1', nome: 'Cookie', custoProduto: 1.0);
      expect(f.temPrecoVenda, isFalse);
      expect(f.margemPercent, 0);
    });

    test('com preço definido: margem = (1 - custo/preco) * 100', () {
      const f =
          FichaTecnica(id: '1', nome: 'Cookie', custoProduto: 1.0, precoVenda: 2.5);
      expect(f.temPrecoVenda, isTrue);
      expect(f.margemPercent, closeTo(60, 0.001));
    });
  });

  group('VendaItemInput.totalLinha', () {
    test('quantidade × preço unitário', () {
      final i = VendaItemInput(descricao: 'x', quantidade: 3, precoUnitario: 2.5);
      expect(i.totalLinha, closeTo(7.5, 0.001));
    });
  });

  group('OrigemVenda', () {
    test('fromApi tolerante, cai em manual', () {
      expect(OrigemVenda.fromApi('csv'), OrigemVenda.csv);
      expect(OrigemVenda.fromApi('vendus'), OrigemVenda.vendus);
      expect(OrigemVenda.fromApi('lixo'), OrigemVenda.manual);
      expect(OrigemVenda.fromApi(null), OrigemVenda.manual);
    });
  });

  test('ymd formata como yyyy-MM-dd com zeros à esquerda', () {
    expect(ymd(DateTime(2026, 1, 5)), '2026-01-05');
  });
}
