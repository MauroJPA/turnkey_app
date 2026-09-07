import 'package:flutter_test/flutter_test.dart';
import 'package:turnkey_app/src/core/formatting/money.dart';
import 'package:turnkey_app/src/features/recipes/domain/recipe.dart';

void main() {
  test('normalização de categorias do meu_app_ia', () {
    expect(CategoriaReceita.fromLegacy('massas'), CategoriaReceita.massa);
    expect(CategoriaReceita.fromLegacy('massas_salgadas'),
        CategoriaReceita.massa);
    expect(CategoriaReceita.fromLegacy('brigadeiros'),
        CategoriaReceita.recheio);
    expect(CategoriaReceita.fromLegacy('ganaches'), CategoriaReceita.recheio);
    expect(CategoriaReceita.fromLegacy('coberturas'),
        CategoriaReceita.cobertura);
    expect(CategoriaReceita.fromLegacy('bebidas'), CategoriaReceita.outra);
    expect(CategoriaReceita.fromLegacy(null), CategoriaReceita.outra);
  });

  test('formatMoney respeita moeda e regra de arredondamento', () {
    expect(
      formatMoney(1.231, symbol: 'R\$', rule: RoundingRule.nearest),
      'R\$1,23',
    );
    expect(
      formatMoney(1.231, symbol: '£', rule: RoundingRule.up),
      '£1,24',
    );
  });
}
