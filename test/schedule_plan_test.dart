import 'package:flutter_test/flutter_test.dart';
import 'package:turnkey_app/src/features/schedule/domain/production_plan.dart';

void main() {
  test('PlanoResposta.fromJson lê necessarios, produzir e custoTotal', () {
    final resp = PlanoResposta.fromJson({
      'necessarios': [
        {
          'ingredienteId': 'i1',
          'nome': 'Farinha T55',
          'fornecedor': 'Makro',
          'gramas': 1594.2,
          'custo': 1.9,
          'emStock': 500.0,
          'aComprar': 1094.2,
        },
        {
          'ingredienteId': 'i2',
          'nome': 'Manteiga',
          'fornecedor': '',
          'gramas': 869.6,
          'custo': 6.2,
          'emStock': 0,
          'aComprar': 869.6,
        },
      ],
      'produzir': [
        {'receitaId': 'r1', 'nome': 'Boston', 'kg': 5.0},
      ],
      'custoTotal': 28.6,
    });

    expect(resp.necessarios, hasLength(2));
    expect(resp.necessarios.first.nome, 'Farinha T55');
    expect(resp.necessarios.first.aComprar, closeTo(1094.2, 1e-9));
    expect(resp.produzir.single.kg, 5.0);
    expect(resp.custoTotal, closeTo(28.6, 1e-9));
    expect(resp.totalAComprar, closeTo(1094.2 + 869.6, 1e-9));
  });

  test('PlanoResposta.fromJson tolera listas em falta', () {
    final resp = PlanoResposta.fromJson({'custoTotal': 0});
    expect(resp.necessarios, isEmpty);
    expect(resp.produzir, isEmpty);
    expect(resp.totalAComprar, 0);
  });

  test('ConclusaoResumo.fromJson lê consumos, saidas e faltas', () {
    final r = ConclusaoResumo.fromJson({
      'consumos': [
        {'nome': 'Farinha', 'gramas': 1594.2},
        {'nome': 'Manteiga', 'gramas': 869.6},
      ],
      'saidas': [
        {'nome': 'Boston', 'gramas': 5000.0},
      ],
      'faltas': ['Recheio X não está publicado como ingrediente'],
      'custoTotal': 28.6,
    });

    expect(r.consumos, hasLength(2));
    expect(r.consumos.first.gramas, closeTo(1594.2, 1e-9));
    expect(r.saidas.single.nome, 'Boston');
    expect(r.faltas.single, contains('não está publicado'));
    expect(r.custoTotal, closeTo(28.6, 1e-9));
  });

  test('EstadoProducao.fromApi cai em planeada para valores desconhecidos', () {
    expect(EstadoProducao.fromApi('concluida'), EstadoProducao.concluida);
    expect(EstadoProducao.fromApi('cancelada'), EstadoProducao.cancelada);
    expect(EstadoProducao.fromApi(null), EstadoProducao.planeada);
    expect(EstadoProducao.fromApi('lixo'), EstadoProducao.planeada);
  });
}
