import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/daily_count/domain/fornada.dart';
import 'package:gc_turnkey/src/features/daily_count/domain/movimento_produto.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  final inicio = DateTime(2026, 10, 4, 10, 0, 0);
  final f = Fornada(
    id: 'a',
    localId: 'loja',
    inicio: inicio,
    duracaoMin: 12,
    itens: const [
      ItemFornada(fichaId: 'f1', quantidade: 6),
      ItemFornada(fichaId: 'f2', quantidade: 4),
    ],
  );

  test('fim, restante e pronta', () {
    expect(f.fim, DateTime(2026, 10, 4, 10, 12));
    expect(f.restante(DateTime(2026, 10, 4, 10, 5)), const Duration(minutes: 7));
    expect(f.pronta(DateTime(2026, 10, 4, 10, 11, 59)), isFalse);
    expect(f.pronta(DateTime(2026, 10, 4, 10, 12)), isTrue);
    expect(f.pronta(DateTime(2026, 10, 4, 10, 20)), isTrue);
    expect(f.totalUnidades, 10);
  });

  test('cronómetro mostra minutos:segundos e passa a horas', () {
    expect(cronometro(const Duration(minutes: 7, seconds: 32)), '07:32');
    expect(cronometro(const Duration(seconds: 5)), '00:05');
    expect(cronometro(const Duration(hours: 1, minutes: 2, seconds: 10)), '1:02:10');
    // atraso (negativo) mostra o valor absoluto
    expect(cronometro(const Duration(minutes: -2, seconds: -10)), '02:10');
  });

  test('duração da fornada = o maior tempo entre os sabores', () {
    expect(duracaoDaFornada(['a', 'b'], {'a': 10, 'b': 14}), 14);
    expect(duracaoDaFornada(['a', 'b'], {'a': 10}), 10);
    expect(duracaoDaFornada(['a'], {'a': 0}), isNull);
    expect(duracaoDaFornada(['x'], {'a': 10}), isNull);
    expect(duracaoDaFornada(const [], const {}), isNull);
  });

  test('lê a fornada do registo (itens e movimentos em json)', () {
    final r = RecordModel({
      'id': 'fo1',
      'local': 'loja',
      'inicio': '2026-10-04 09:00:00.000Z',
      'duracao_min': 15,
      'estado': 'no_forno',
      'itens': [
        {'ficha': 'f1', 'quantidade': 6},
        {'ficha': 'f2', 'quantidade': 0}, // ignorada
        {'ficha': '', 'quantidade': 3}, // ignorada
      ],
      'movimentos': ['m1', 'm2'],
    });
    final x = Fornada.fromRecord(r);
    expect(x.id, 'fo1');
    expect(x.localId, 'loja');
    expect(x.duracaoMin, 15);
    expect(x.estado, EstadoFornada.noForno);
    expect(x.itens, hasLength(1));
    expect(x.itens.single.fichaId, 'f1');
    expect(x.movimentoIds, ['m1', 'm2']);
    expect(x.inicio.toUtc(), DateTime.utc(2026, 10, 4, 9));
  });

  test('o consumo próprio é um motivo de desperdício', () {
    expect(
      MotivoDesperdicio.fromApi('consumo_proprio'),
      MotivoDesperdicio.consumoProprio,
    );
    expect(MotivoDesperdicio.consumoProprio.label, 'Consumo próprio');
  });
}
