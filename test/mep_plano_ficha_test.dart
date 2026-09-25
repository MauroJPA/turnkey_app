import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/mise_en_place/domain/mep_plano.dart';

void main() {
  test('MepPlano de um produto final: massa primeiro e recheios listados', () {
    final p = MepPlano.fromJson({
      'fichaId': 'f1',
      'nome': 'Boston',
      'receitaId': 'massa1',
      'kg': 1,
      'unidades': 10,
      'formato': 'Recheado',
      'formatoId': 'fmt1',
      'comprar': [
        {'ingredienteId': 'i1', 'nome': 'Farinha', 'gramas': 500, 'emStock': 100},
      ],
      'intermedios': [
        {'receitaId': 'massa1', 'nome': 'Massa Boston', 'gramas': 1000, 'eMassa': true},
        {'receitaId': 'r2', 'nome': 'Creme', 'gramas': 300},
      ],
    });
    expect(p.fichaId, 'f1');
    expect(p.formatoId, 'fmt1');
    expect(p.unidades, 10);
    expect(p.intermedios.first.eMassa, isTrue);
    expect(p.intermedios[1].eMassa, isFalse);
    expect(p.comprar.single.faltaStock, isTrue);
  });

  test('MepPlano de receita não tem ficha', () {
    final p = MepPlano.fromJson({'receitaId': 'r', 'nome': 'X', 'kg': 2});
    expect(p.fichaId, isEmpty);
    expect(p.intermedios, isEmpty);
  });
}
