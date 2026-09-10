import 'package:flutter_test/flutter_test.dart';
import 'package:turnkey_app/src/features/inventory/domain/stock_item.dart';

StockItem _item({
  StockTipo tipo = StockTipo.ingrediente,
  bool favorito = false,
  double usos = 0,
}) =>
    StockItem(
      tipo: tipo,
      id: 'x',
      nome: 'Farinha',
      quantidade: 500,
      custoUnitario: 0.01,
      favorito: favorito,
      usos: usos,
    );

void main() {
  test('favorito e usos têm defaults e sobrevivem ao copyWith', () {
    final base = _item();
    expect(base.favorito, isFalse);
    expect(base.usos, 0);

    final fav = base.copyWith(favorito: true);
    expect(fav.favorito, isTrue);
    expect(fav.usos, base.usos);
    expect(fav.nome, base.nome);

    // copyWith sem favorito mantém o valor
    expect(fav.copyWith(quantidade: 1).favorito, isTrue);
  });

  test('valor = quantidade * custoUnitario', () {
    expect(_item().valor, closeTo(5, 1e-9));
  });
}
