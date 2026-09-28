import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/core/formatting/money.dart';
import 'package:gc_turnkey/src/features/recipes/domain/recipe.dart';

void main() {
  test('normalização de categorias do meu_app_ia', () {
    expect(categoriaReceitaDeTextoLegado('massas'), 'Massa');
    expect(categoriaReceitaDeTextoLegado('massas_salgadas'), 'Massa');
    expect(categoriaReceitaDeTextoLegado('brigadeiros'), 'Recheio');
    expect(categoriaReceitaDeTextoLegado('ganaches'), 'Recheio');
    expect(categoriaReceitaDeTextoLegado('coberturas'), 'Cobertura');
    expect(categoriaReceitaDeTextoLegado('bebidas'), 'Outra');
    expect(categoriaReceitaDeTextoLegado(null), 'Outra');
  });

  test('formatMoney respeita moeda e regra de arredondamento', () {
    expect(
      formatMoney(1.231, symbol: 'R\$', rule: RoundingRule.nearest),
      'R\$1,23',
    );
    expect(formatMoney(1.231, symbol: '£', rule: RoundingRule.up), '£1,24');
  });
}
