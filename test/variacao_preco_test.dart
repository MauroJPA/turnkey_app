import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/inventory/domain/variacao_preco.dart';
import 'package:gc_turnkey/src/features/pricing/domain/cost_config.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  test('lê a variação e as fichas afetadas do servidor', () {
    final v = VariacaoPreco.fromRecord(
      RecordModel({
        'id': 'v1',
        'ingrediente': 'i1',
        'ingrediente_nome': 'Farinha',
        'antes': 2.0,
        'depois': 2.4,
        'pct': 20.0,
        'created': '2026-10-05 22:14:41.230Z',
        'afetadas': [
          {
            'id': 'f1',
            'nome': 'Cookie',
            'custo_antes': 0.35,
            'custo_depois': 0.39,
            'preco_venda': 1.5,
          },
        ],
      }),
    );
    expect(v.subiu, isTrue);
    expect(v.subidaAcima(5), isTrue);
    expect(v.subidaAcima(25), isFalse);
    expect(v.criada.year, 2026);
    expect(v.afetadas.single.nome, 'Cookie');
    expect(v.afetadas.single.variacaoCusto, closeTo(0.04, 1e-9));
  });

  test('margem antes e depois sobre o preço sem IVA', () {
    const f = FichaAfetada(
      id: 'f',
      nome: 'Cookie',
      custoAntes: 0.35,
      custoDepois: 0.39,
      precoVenda: 1.5,
    );
    // sem IVA: 1,50 → margem = 1 − 0,35/1,5
    expect(f.margem(0.35, 0), closeTo(76.67, 0.01));
    // com 23% de IVA o preço limpo é 1,2195 → margem menor
    expect(f.margem(0.35, 23)!, lessThan(f.margem(0.35, 0)!));
    expect(f.margem(0.39, 23)!, lessThan(f.margem(0.35, 23)!));
    const sem = FichaAfetada(id: 'x', nome: 'x', custoAntes: 1, custoDepois: 1);
    expect(sem.margem(1, 23), isNull);
  });

  test('tolera registos sem fichas ou com JSON mal formado', () {
    final v = VariacaoPreco.fromRecord(
      RecordModel({'id': 'v', 'afetadas': 'lixo'}),
    );
    expect(v.afetadas, isEmpty);
    expect(v.pct, 0);
  });

  test('limiar de aviso: 5% por omissão e vai no corpo', () {
    expect(const CostConfig().alertaPrecoPct, 5);
    expect(const CostConfig(alertaPrecoPct: 8).toBody()['alerta_preco_pct'], 8);
    expect(const CostConfig(alertaPrecoPct: 0).toBody()['alerta_preco_pct'], 5);
  });
}
