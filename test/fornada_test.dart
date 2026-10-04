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
    duracaoMin: 14,
    itens: const [
      ItemFornada(fichaId: 'f1', quantidade: 6, duracaoMin: 12),
      ItemFornada(fichaId: 'f2', quantidade: 4, duracaoMin: 14),
    ],
  );

  test('fim, restante e pronta da fornada inteira (o maior tempo)', () {
    expect(f.fim, DateTime(2026, 10, 4, 10, 14));
    expect(f.restante(DateTime(2026, 10, 4, 10, 5)), const Duration(minutes: 9));
    expect(f.pronta(DateTime(2026, 10, 4, 10, 13, 59)), isFalse);
    expect(f.pronta(DateTime(2026, 10, 4, 10, 14)), isTrue);
    expect(f.totalUnidades, 10);
  });

  test('cada sabor tem o seu tempo: falta, passou, pronto', () {
    final agora = DateTime(2026, 10, 4, 10, 12, 30);
    final f1 = f.itens[0]; // 12 min
    final f2 = f.itens[1]; // 14 min
    expect(f.temTemposDiferentes, isTrue);
    expect(f.prontoItem(f1, agora), isTrue);
    expect(f.prontoItem(f2, agora), isFalse);
    expect(f.restanteDe(f1, agora), const Duration(seconds: -30));
    expect(f.restanteDe(f2, agora), const Duration(seconds: 90));
    expect(f.decorrido(agora), const Duration(minutes: 12, seconds: 30));
    // o que sai primeiro vem à frente
    expect(f.noForno(agora).map((i) => i.fichaId), ['f1', 'f2']);
  });

  test('tirar um sabor deixa o outro no forno; tirar todos conclui', () {
    final um = f.comItemTirado('f1');
    expect(um.itens[0].tirado, isTrue);
    expect(um.itens[1].tirado, isFalse);
    expect(um.todosTirados, isFalse);
    expect(um.noForno(inicio).map((i) => i.fichaId), ['f2']);
    expect(um.comItemTirado('f2').todosTirados, isTrue);
  });

  test('saboresNoForno junta fornadas e ordena pelo que sai primeiro', () {
    final outra = Fornada(
      id: 'b',
      localId: 'loja',
      inicio: DateTime(2026, 10, 4, 10, 6),
      duracaoMin: 8,
      itens: const [ItemFornada(fichaId: 'f3', quantidade: 2, duracaoMin: 8)],
    );
    final r = saboresNoForno([f, outra], DateTime(2026, 10, 4, 10, 7));
    // f3 sai às 10:14, f1 às 10:12, f2 às 10:14 → f1, depois f2/f3
    expect(r.first.item.fichaId, 'f1');
    expect(r, hasLength(3));
    final concluida = Fornada(
      id: 'c',
      localId: 'loja',
      inicio: inicio,
      duracaoMin: 5,
      estado: EstadoFornada.tirada,
      itens: const [ItemFornada(fichaId: 'f9', quantidade: 1, duracaoMin: 5)],
    );
    expect(saboresNoForno([concluida], inicio), isEmpty);
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
        {'ficha': 'f1', 'quantidade': 6, 'duracao_min': 12, 'tirado': true},
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
    expect(x.itens.single.duracaoMin, 12);
    expect(x.itens.single.tirado, isTrue);
    expect(x.movimentoIds, ['m1', 'm2']);
    expect(x.inicio.toUtc(), DateTime.utc(2026, 10, 4, 9));
  });

  test('registos antigos (sem tempo por sabor) usam o tempo da fornada', () {
    final x = Fornada.fromRecord(
      RecordModel({
        'id': 'fo2',
        'local': 'loja',
        'inicio': '2026-10-04 09:00:00.000Z',
        'duracao_min': 13,
        'estado': 'no_forno',
        'itens': [
          {'ficha': 'f1', 'quantidade': 3},
        ],
      }),
    );
    expect(x.itens.single.duracaoMin, 13);
    expect(x.itens.single.tirado, isFalse);
  });

  test('o consumo próprio é um motivo de desperdício', () {
    expect(
      MotivoDesperdicio.fromApi('consumo_proprio'),
      MotivoDesperdicio.consumoProprio,
    );
    expect(MotivoDesperdicio.consumoProprio.label, 'Consumo próprio');
  });
}
