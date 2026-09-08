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

  test('PlanoProduzir.fromJson lê formato/recheio/unidades/prioridade', () {
    final resp = PlanoResposta.fromJson({
      'necessarios': [
        {
          'ingredienteId': 'i1',
          'nome': 'Bicarbonato',
          'gramas': 1594.0,
          'aComprar': 1594.0,
          'embalagemG': 1000.0,
          'aComprarSacos': 2,
        },
      ],
      'produzir': [
        {
          'receitaId': 'r1',
          'nome': 'Boston',
          'kg': 10.0,
          'unidades': 83,
          'formato': 'Recheado',
          'recheio': 'Brigadeiro_Rio',
          'prioridade': 'alta',
          'horaLimite': '14:00',
        },
      ],
      'custoTotal': 67.7,
    });
    final p = resp.produzir.single;
    expect(p.unidades, 83);
    expect(p.formato, 'Recheado');
    expect(p.recheio, 'Brigadeiro_Rio');
    expect(p.prioridade, Prioridade.alta);
    expect(p.horaLimite, '14:00');
    expect(resp.necessarios.single.aComprarSacos, 2);
    expect(resp.necessarios.single.embalagemG, 1000.0);
  });

  test('tituloPadraoProducao: hoje vs data, com nomes de receitas', () {
    final hoje = DateTime.now();
    expect(tituloPadraoProducao(hoje, const []), 'Produção de hoje');
    expect(
      tituloPadraoProducao(hoje, const ['Massa - Rio', 'Brigadeiro - Rio']),
      'Produção de hoje - Massa - Rio, Brigadeiro - Rio',
    );
    final d = DateTime(2026, 9, 15);
    expect(tituloPadraoProducao(d, const []), 'Produção 15/09/2026');
    expect(
      tituloPadraoProducao(d, const ['A', 'B', 'C', 'D']),
      'Produção 15/09/2026 - A, B, C…',
    );
  });

  test('Prioridade.fromApi tolerante; peso ordena alta<media<baixa', () {
    expect(Prioridade.fromApi('alta'), Prioridade.alta);
    expect(Prioridade.fromApi(null), Prioridade.media);
    expect(Prioridade.fromApi('xpto'), Prioridade.media);
    expect(Prioridade.alta.peso < Prioridade.baixa.peso, isTrue);
  });

  test('EstadoProducao.fromApi cai em planeada para valores desconhecidos', () {
    expect(EstadoProducao.fromApi('concluida'), EstadoProducao.concluida);
    expect(EstadoProducao.fromApi('cancelada'), EstadoProducao.cancelada);
    expect(EstadoProducao.fromApi(null), EstadoProducao.planeada);
    expect(EstadoProducao.fromApi('lixo'), EstadoProducao.planeada);
  });
}
