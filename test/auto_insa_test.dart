import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/ingredients/domain/auto_insa.dart';

void main() {
  test('ResumoAutoInsa.fromJson lê aplicados, total e os resultados', () {
    final r = ResumoAutoInsa.fromJson({
      'aplicados': 2,
      'total': 4,
      'resultados': [
        {
          'ingredienteId': 'i1',
          'nome': 'Açúcar branco',
          'estado': 'preenchido',
          'referencia': {'id': 'r9', 'nome': 'Açúcar branco', 'score': 1.7},
          'candidatos': [
            {
              'id': 'r9',
              'nome': 'Açúcar branco',
              'grupo': 'Açúcar e similares',
              'score': 1.7,
              'nutri': {'energia_kcal': 397, 'hidratos_g': 99.3},
              'alergenios': <String>[],
            },
          ],
        },
        {
          'ingredienteId': 'i2',
          'nome': 'Ovo',
          'estado': 'revisao',
          'candidatos': [
            {
              'id': 'r1',
              'nome': 'Ovo de galinha, cru',
              'grupo': 'Ovos e ovoprodutos',
              'score': 1.02,
              'nutri': {'energia_kcal': 143, 'proteina_g': 12.5},
              'alergenios': ['Ovos'],
            },
            {
              'id': 'r2',
              'nome': 'Ovo de codorniz, cru',
              'score': 1.02,
              'nutri': {'energia_kcal': 150},
              'alergenios': ['Ovos'],
            },
          ],
        },
        {
          'ingredienteId': 'i3',
          'nome': 'Xarope XPTO',
          'estado': 'sem_candidato',
          'candidatos': <dynamic>[],
        },
      ],
    });

    expect(r.aplicados, 2);
    expect(r.total, 4);
    expect(r.resultados, hasLength(3));
    expect(r.porRever, 1);
    expect(r.semCorrespondencia, 1);

    final ovo = r.resultados[1];
    expect(ovo.estado, EstadoAutoInsa.revisao);
    expect(ovo.candidatos, hasLength(2));
    expect(ovo.candidatos.first.nome, 'Ovo de galinha, cru');
    expect(ovo.candidatos.first.alergenios, ['Ovos']);
    expect(ovo.candidatos.first.nutri.kcal, 143);
    expect(ovo.candidatos.first.percentagem, 100); // score>1 -> clamp

    final acucar = r.resultados.first;
    expect(acucar.estado, EstadoAutoInsa.preenchido);
    expect(acucar.referenciaNome, 'Açúcar branco');
    expect(acucar.candidatos.first.nutri.hidratos, 99.3);
  });

  test('InsaCandidato tolera nutri/alergenios em falta', () {
    final c = InsaCandidato.fromJson({'id': 'x', 'nome': 'Sal', 'score': 1.1});
    expect(c.nome, 'Sal');
    expect(c.nutri.kcal, 0);
    expect(c.alergenios, isEmpty);
    expect(c.percentagem, 100);
  });
}
