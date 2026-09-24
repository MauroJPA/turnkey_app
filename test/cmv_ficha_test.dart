import 'package:flutter_test/flutter_test.dart';
import 'package:turnkey_app/src/features/pricing/domain/cost_config.dart';
import 'package:turnkey_app/src/features/tech_sheets/domain/tech_sheet.dart';

void main() {
  test('CMV esperado vem da configuração; real do preço de venda praticado', () {
    // 75% em outras rubricas → CMV esperado 25%.
    const config = CostConfig(salario: 30, aluguel: 15, margemLucro: 30);
    expect(config.cmvPercent, 25);

    const f = FichaTecnica(
      id: '1',
      nome: 'Boston',
      custoProduto: 1.5,
      precoVenda: 5,
    );
    expect(f.cmvRealPercent(), closeTo(30, 1e-9));
    // usa o custo recalculado quando fornecido
    expect(f.cmvRealPercent(1.0), closeTo(20, 1e-9));
  });

  test('sem preço de venda ou sem custo não há CMV real', () {
    const semPreco = FichaTecnica(id: '1', nome: 'X', custoProduto: 2);
    expect(semPreco.cmvRealPercent(), isNull);
    const semCusto = FichaTecnica(id: '2', nome: 'Y', precoVenda: 4);
    expect(semCusto.cmvRealPercent(), isNull);
  });
}
