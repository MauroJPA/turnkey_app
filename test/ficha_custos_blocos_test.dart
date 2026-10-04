import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/tech_sheets/application/tech_sheets_providers.dart';
import 'package:gc_turnkey/src/features/tech_sheets/domain/tech_sheet.dart';
import 'package:gc_turnkey/src/features/tech_sheets/domain/tech_sheet_item.dart';

void main() {
  ItemFicha item(
    SlotFicha slot,
    double qtd,
    double cpg, {
    String? embalagemId,
  }) => ItemFicha(
    id: '${slot.api}$qtd',
    fichaId: 'f',
    slot: slot,
    embalagemId: embalagemId,
    quantidadeG: qtd,
    custoPorGramaResolvido: cpg,
  );

  final ficha = const FichaTecnica(id: 'f', nome: 'Cookie');

  test('slot da embalagem para plataformas: api, rótulo e tipo', () {
    expect(SlotFicha.fromApi('embalagem_plataforma'), SlotFicha.embalagemPlataforma);
    expect(SlotFicha.embalagemPlataforma.api, 'embalagem_plataforma');
    expect(SlotFicha.embalagemPlataforma.label, 'Embalagem para plataformas');
    expect(SlotFicha.embalagemPlataforma.ehEmbalagem, isTrue);
    expect(SlotFicha.embalagem.ehEmbalagem, isTrue);
    expect(SlotFicha.massa.ehEmbalagem, isFalse);
  });

  test('custo na loja não inclui a embalagem de plataformas', () {
    final d = FichaDetail(
      ficha: ficha,
      itens: [
        item(SlotFicha.massa, 80, 0.01), // 0,80
        item(SlotFicha.recheioBase, 20, 0.02), // 0,40
        item(SlotFicha.embalagem, 1, 0.15, embalagemId: 'e1'), // 0,15
        item(SlotFicha.embalagemPlataforma, 1, 0.30, embalagemId: 'e2'), // 0,30
      ],
    );
    expect(d.custoMateriaPrima, closeTo(1.20, 1e-9));
    expect(d.custoEmbalagem, closeTo(0.15, 1e-9));
    expect(d.custoPreview, closeTo(1.35, 1e-9)); // custo na loja
    expect(d.custoEmbalagemPlataforma, closeTo(0.30, 1e-9));
    expect(d.custoPlataforma, closeTo(1.65, 1e-9));
    expect(d.temEmbalagemPlataforma, isTrue);
  });

  test('sem embalagem de plataformas, o custo é igual nos dois sítios', () {
    final d = FichaDetail(
      ficha: ficha,
      itens: [item(SlotFicha.massa, 100, 0.01)],
    );
    expect(d.temEmbalagemPlataforma, isFalse);
    expect(d.custoPlataforma, d.custoPreview);
  });

  test('as embalagens (peças) não pesam no produto', () {
    final d = FichaDetail(
      ficha: ficha,
      itens: [
        item(SlotFicha.massa, 80, 0.01),
        item(SlotFicha.embalagem, 3, 0.1, embalagemId: 'e1'),
        item(SlotFicha.embalagemPlataforma, 2, 0.1, embalagemId: 'e2'),
      ],
    );
    expect(d.pesoTotal, 80);
  });
}
