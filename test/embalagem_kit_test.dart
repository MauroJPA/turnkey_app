import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/packaging/application/embalagem_kit_providers.dart';
import 'package:gc_turnkey/src/features/packaging/domain/embalagem_kit.dart';

void main() {
  test('custoLinha = custo/un da embalagem × quantidade', () {
    const linha = EmbalagemKitItem(
      id: 'l1',
      kitId: 'k1',
      embalagemId: 'e1',
      quantidade: 2,
      nomeEmbalagem: 'Adesivo',
      custoUnidadeEmbalagem: 0.02,
    );
    expect(linha.custoLinha, closeTo(0.04, 1e-9));
    expect(linha.nome, 'Adesivo');
  });

  test('KitDetalhe.custoSoma soma as linhas', () {
    final d = KitDetalhe(
      kit: const EmbalagemKit(id: 'k1', nome: 'Take-away'),
      itens: const [
        EmbalagemKitItem(
          id: 'l1',
          kitId: 'k1',
          embalagemId: 'saq',
          quantidade: 1,
          custoUnidadeEmbalagem: 0.05,
        ),
        EmbalagemKitItem(
          id: 'l2',
          kitId: 'k1',
          embalagemId: 'cx',
          quantidade: 1,
          custoUnidadeEmbalagem: 2.0,
        ),
        EmbalagemKitItem(
          id: 'l3',
          kitId: 'k1',
          embalagemId: 'ade',
          quantidade: 2,
          custoUnidadeEmbalagem: 0.02,
        ),
      ],
    );
    expect(d.custoSoma, closeTo(2.09, 1e-9));
  });

  test('EmbalagemKitInput.toBody normaliza nome e mantém deletado=false', () {
    final b = EmbalagemKitInput(nome: '  Loja  ', descricao: ' 1 saqueta ')
        .toBody();
    expect(b['nome'], 'Loja');
    expect(b['descricao'], '1 saqueta');
    expect(b['deletado'], false);
  });
}
