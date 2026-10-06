import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/inventory/domain/sugestao_preco.dart';

void main() {
  test('mantém a margem de antes depois de o custo subir', () {
    // preço 1,50 com IVA 6 % → 1,415 sem IVA; custo 0,40 → margem ~71,7 %
    final s = sugerirPreco(
      custoAntes: 0.40,
      custoAtual: 0.50,
      precoAtualComIva: 1.50,
      ivaPct: 6,
    )!;
    expect(s.margemAlvo, closeTo(71.7, 0.1));
    expect(s.margemAtual, closeTo(64.7, 0.1));
    // 0,50 / (1 − 0,717) × 1,06 ≈ 1,87 → sobe ao múltiplo de 5 cêntimos
    expect(s.precoSugerido, 1.90);
    expect(s.aumento, closeTo(0.40, 1e-9));
    // com o preço novo a margem fica >= à de antes
    final margemNova = (1 - 0.50 / (s.precoSugerido / 1.06)) * 100;
    expect(margemNova, greaterThanOrEqualTo(s.margemAlvo - 1e-9));
  });

  test('sem IVA e preço redondo', () {
    // preço 2,00, custo 1,00 → margem 50 %; custo 1,20 → preço 2,40
    final s = sugerirPreco(
      custoAntes: 1.0,
      custoAtual: 1.2,
      precoAtualComIva: 2.0,
      ivaPct: 0,
    )!;
    expect(s.margemAlvo, closeTo(50, 1e-9));
    expect(s.precoSugerido, 2.40);
  });

  test('o custo desceu ou ficou igual: nada a sugerir', () {
    expect(
      sugerirPreco(
        custoAntes: 1,
        custoAtual: 0.9,
        precoAtualComIva: 2,
        ivaPct: 0,
      ),
      isNull,
    );
    expect(
      sugerirPreco(
        custoAntes: 1,
        custoAtual: 1,
        precoAtualComIva: 2,
        ivaPct: 0,
      ),
      isNull,
    );
  });

  test('sem preço de venda ou sem custo antigo: nada a sugerir', () {
    expect(
      sugerirPreco(
        custoAntes: 1,
        custoAtual: 1.2,
        precoAtualComIva: 0,
        ivaPct: 0,
      ),
      isNull,
    );
    expect(
      sugerirPreco(
        custoAntes: 0,
        custoAtual: 1.2,
        precoAtualComIva: 2,
        ivaPct: 0,
      ),
      isNull,
    );
  });

  test('já vendia com prejuízo: não há margem de antes a recuperar', () {
    expect(
      sugerirPreco(
        custoAntes: 2.5,
        custoAtual: 3,
        precoAtualComIva: 2,
        ivaPct: 0,
      ),
      isNull,
    );
  });

  test('o preço já foi subido o suficiente: a sugestão desaparece', () {
    // antes: preço 2,00 / custo 1,00 (50 %); agora custo 1,20 mas preço já 2,40
    expect(
      sugerirPreco(
        custoAntes: 1.0,
        custoAtual: 1.2,
        precoAntesComIva: 2.0,
        precoAtualComIva: 2.4,
        ivaPct: 0,
      ),
      isNull,
    );
  });

  test('o preço subiu a meio caminho: sugere só o que falta', () {
    // antes 2,00 (margem 50 %); custo 1,20 pede 2,40; já está a 2,20
    final s = sugerirPreco(
      custoAntes: 1.0,
      custoAtual: 1.2,
      precoAntesComIva: 2.0,
      precoAtualComIva: 2.2,
      ivaPct: 0,
    )!;
    expect(s.margemAlvo, closeTo(50, 1e-9));
    expect(s.precoSugerido, 2.40);
    expect(s.precoAtual, 2.2);
  });

  test('variação pequena que o arredondamento não muda: nada a sugerir', () {
    // custo sobe 0,1 cêntimo num preço de 2,00: o novo preço arredondado = atual
    expect(
      sugerirPreco(
        custoAntes: 1.0,
        custoAtual: 1.001,
        precoAtualComIva: 2.0,
        ivaPct: 0,
      ),
      isNull,
    );
  });
}
