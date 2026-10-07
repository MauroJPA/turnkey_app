import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/people/domain/ponto.dart';
import 'package:gc_turnkey/src/features/quiosque/domain/colaborador.dart';
import 'package:gc_turnkey/src/features/quiosque/domain/fila_offline.dart';

void main() {
  var n = 0;
  RegistoPonto r(
    String pessoa,
    TipoPonto t,
    DateTime q, {
    String nome = 'Ana',
  }) => RegistoPonto(
    id: '${n++}',
    pessoa: pessoa,
    nome: nome,
    tipo: t,
    dataHora: q,
  );

  // terça 6 out 2026
  DateTime h(int hora, [int min = 0, int dia = 6]) =>
      DateTime(2026, 10, dia, hora, min);
  final agora = DateTime(2026, 10, 6, 18);

  test('o que se pode marcar a seguir', () {
    expect(proximosPontos(null), [TipoPonto.entrada]);
    expect(proximosPontos(TipoPonto.saida), [TipoPonto.entrada]);
    expect(proximosPontos(TipoPonto.entrada), [
      TipoPonto.pausaInicio,
      TipoPonto.saida,
    ]);
    expect(proximosPontos(TipoPonto.pausaFim), [
      TipoPonto.pausaInicio,
      TipoPonto.saida,
    ]);
    expect(proximosPontos(TipoPonto.pausaInicio), [TipoPonto.pausaFim]);
  });

  test('uma jornada normal desconta a pausa', () {
    final j = calcularJornadas([
      r('u:1', TipoPonto.entrada, h(8)),
      r('u:1', TipoPonto.pausaInicio, h(12)),
      r('u:1', TipoPonto.pausaFim, h(12, 30)),
      r('u:1', TipoPonto.saida, h(16, 30)),
    ], agora).single;
    expect(j.pausa, const Duration(minutes: 30));
    expect(j.trabalhado(agora), const Duration(hours: 8));
    expect(j.avisos, isEmpty);
    expect(j.aTrabalhar, isFalse);
    expect(j.registos, hasLength(4));
  });

  test('quem ainda não saiu hoje está a trabalhar e conta até agora', () {
    final j = calcularJornadas([
      r('u:1', TipoPonto.entrada, h(9)),
    ], agora).single;
    expect(j.aTrabalhar, isTrue);
    expect(j.trabalhado(agora), const Duration(hours: 9));
    expect(j.avisos, isEmpty);
  });

  test('saída esquecida de um dia anterior não conta e avisa', () {
    final j = calcularJornadas([
      r('u:1', TipoPonto.entrada, h(8, 0, 5)),
    ], agora).single;
    expect(j.aTrabalhar, isFalse);
    expect(j.semSaida, isTrue);
    expect(j.trabalhado(agora), Duration.zero);
    expect(j.avisos, contains('Falta a saída'));
  });

  test('saída 20 horas depois da entrada é esquecimento', () {
    final j = calcularJornadas([
      r('u:1', TipoPonto.entrada, h(8, 0, 4)),
      r('u:1', TipoPonto.saida, h(4, 0, 5)),
    ], agora).single;
    expect(j.semSaida, isTrue);
    expect(j.trabalhado(agora), Duration.zero);
  });

  test('jornada que passa da meia-noite conta para o dia da entrada', () {
    final j = calcularJornadas([
      r('u:1', TipoPonto.entrada, h(22, 0, 5)),
      r('u:1', TipoPonto.saida, h(6, 0, 6)),
    ], agora).single;
    expect(j.dia, DateTime(2026, 10, 5));
    expect(j.trabalhado(agora), const Duration(hours: 8));
  });

  test('marcações fora de ordem não se perdem', () {
    final js = calcularJornadas([
      r('u:1', TipoPonto.saida, h(8)),
      r('u:1', TipoPonto.entrada, h(9)),
      r('u:1', TipoPonto.entrada, h(10)),
      r('u:1', TipoPonto.pausaFim, h(11)),
      r('u:1', TipoPonto.saida, h(12)),
    ], agora);
    final avisos = js.expand((j) => j.avisos).toList();
    expect(avisos, contains('Saída sem entrada'));
    expect(avisos, contains('Falta a saída')); // a entrada das 9 ficou aberta
    expect(avisos, contains('Fim da pausa sem entrada'));
    // a segunda entrada fechou normalmente às 12
    expect(
      js.any((j) => j.entrada == h(10) && j.saida == h(12) && j.avisos.isEmpty),
      isTrue,
    );
  });

  test('saída com a pausa aberta fecha a pausa e avisa', () {
    final j = calcularJornadas([
      r('u:1', TipoPonto.entrada, h(8)),
      r('u:1', TipoPonto.pausaInicio, h(12)),
      r('u:1', TipoPonto.saida, h(13)),
    ], agora).single;
    expect(j.pausa, const Duration(hours: 1));
    expect(j.trabalhado(agora), const Duration(hours: 4));
    expect(j.avisos, contains('Pausa sem fim'));
  });

  test('totais por pessoa e CSV', () {
    final js = calcularJornadas([
      r('u:1', TipoPonto.entrada, h(8)),
      r('u:1', TipoPonto.saida, h(12)),
      r('u:1', TipoPonto.entrada, h(8, 0, 5)),
      r('u:1', TipoPonto.saida, h(12, 30, 5)),
      r('c:2', TipoPonto.entrada, h(9), nome: 'Rui'),
    ], agora);
    final t = totaisPorPessoa(js, agora);
    expect(t.map((x) => x.nome), ['Ana', 'Rui']);
    expect(t[0].trabalhado, const Duration(hours: 8, minutes: 30));
    expect(t[0].dias, 2);
    expect(t[1].aTrabalhar, isTrue);
    final csv = jornadasCsv(js, agora);
    expect(
      csv.split('\n').first,
      'Pessoa;Dia;Entrada;Saída;Pausa;Trabalhado;Avisos',
    );
    expect(csv, contains('"Ana";2026-10-05;08:00;12:30;0m;4h 30m;""'));
  });

  test('formatar duração', () {
    expect(formatarDuracao(Duration.zero), '0m');
    expect(formatarDuracao(const Duration(minutes: 45)), '45m');
    expect(formatarDuracao(const Duration(hours: 7, minutes: 5)), '7h 05m');
  });

  test('a chave da pessoa é a conta ou o colaborador', () {
    expect(
      chavePessoa(const Colaborador(id: 'equipa:u1', nome: 'A', userId: 'u1')),
      'u:u1',
    );
    expect(chavePessoa(const Colaborador(id: 'abc', nome: 'B')), 'c:abc');
  });

  group('fila offline com ponto', () {
    test('uma marcação pendente guarda-se e lê-se', () {
      final p = RegistoPendente(
        id: 'abcdefghij12345',
        controloId: '',
        dataHora: h(8),
        conforme: true,
        ponto: const PontoPendente(pessoa: 'c:2', nome: 'Rui', tipo: 'entrada'),
      );
      final lida = lerFila(codificarFila([p])).single;
      expect(lida.ponto?.pessoa, 'c:2');
      expect(lida.ponto?.tipo, 'entrada');
      expect(lida.maisUmaTentativa().ponto?.nome, 'Rui');
    });

    test('registo HACCP sem controlo continua a ser inválido', () {
      expect(
        lerFila(
          '[{"id":"abcdefghij12345","controlo":"","dataHora":"2026-10-07T09:00:00Z"}]',
        ),
        isEmpty,
      );
    });

    test('o ponto pendente não mexe nas tarefas', () {
      final p = RegistoPendente(
        id: 'abcdefghij12345',
        controloId: '',
        dataHora: agora,
        conforme: true,
        ponto: const PontoPendente(pessoa: 'c:2', nome: 'R', tipo: 'saida'),
      );
      expect(comPendentes(const [], [p], agora), isEmpty);
    });

    test('estado do ponto: guardar, ler e juntar pela mais recente', () {
      final a = {'c:2': UltimoPonto(TipoPonto.entrada, h(8))};
      final lido = lerEstadoPonto(codificarEstadoPonto(a));
      expect(lido['c:2']?.tipo, TipoPonto.entrada);
      final j = juntarEstadoPonto(a, {
        'c:2': UltimoPonto(TipoPonto.saida, h(12)),
        'u:1': UltimoPonto(TipoPonto.entrada, h(9)),
      });
      expect(j['c:2']?.tipo, TipoPonto.saida);
      expect(j.keys, containsAll(['c:2', 'u:1']));
      // a mais antiga não ganha
      final antiga = juntarEstadoPonto(j, {
        'c:2': UltimoPonto(TipoPonto.entrada, h(7)),
      });
      expect(antiga['c:2']?.tipo, TipoPonto.saida);
      expect(lerEstadoPonto('lixo'), isEmpty);
    });
  });

  group('pausa automática na saída', () {
    const meia = Duration(minutes: 30);
    Duration meiaHora(String pessoa, DateTime entrada) => meia;

    test('sem pausa marcada, a saída preenche a da escala', () {
      final j = calcularJornadas(
        [
          r('u:1', TipoPonto.entrada, h(8)),
          r('u:1', TipoPonto.saida, h(16, 30)),
        ],
        agora,
        pausaAutomatica: meiaHora,
      ).single;
      expect(j.pausa, meia);
      expect(j.pausaAutomatica, isTrue);
      expect(j.trabalhado(agora), const Duration(hours: 8));
      expect(j.avisos, isEmpty);
    });

    test('se a pausa foi marcada, não se muda nada', () {
      final j = calcularJornadas(
        [
          r('u:1', TipoPonto.entrada, h(8)),
          r('u:1', TipoPonto.pausaInicio, h(12)),
          r('u:1', TipoPonto.pausaFim, h(12, 45)),
          r('u:1', TipoPonto.saida, h(16, 30)),
        ],
        agora,
        pausaAutomatica: meiaHora,
      ).single;
      expect(j.pausa, const Duration(minutes: 45));
      expect(j.pausaAutomatica, isFalse);
    });

    test('pausa começada e sem fim também conta como marcada', () {
      final j = calcularJornadas(
        [
          r('u:1', TipoPonto.entrada, h(8)),
          r('u:1', TipoPonto.pausaInicio, h(12)),
          r('u:1', TipoPonto.saida, h(12, 20)),
        ],
        agora,
        pausaAutomatica: meiaHora,
      ).single;
      expect(j.pausa, const Duration(minutes: 20));
      expect(j.pausaAutomatica, isFalse);
    });

    test('quem ainda está a trabalhar só a recebe na saída', () {
      final j = calcularJornadas(
        [r('u:1', TipoPonto.entrada, h(9))],
        agora,
        pausaAutomatica: meiaHora,
      ).single;
      expect(j.aTrabalhar, isTrue);
      expect(j.pausa, Duration.zero);
      expect(j.pausaAutomatica, isFalse);
      expect(j.trabalhado(agora), const Duration(hours: 9));
    });

    test('nunca é maior do que a jornada', () {
      final j = calcularJornadas(
        [
          r('u:1', TipoPonto.entrada, h(8)),
          r('u:1', TipoPonto.saida, h(8, 20)),
        ],
        agora,
        pausaAutomatica: meiaHora,
      ).single;
      expect(j.pausa, const Duration(minutes: 20));
      expect(j.trabalhado(agora), Duration.zero);
    });

    test('sem pausa na escala (zero) não preenche nada', () {
      final j = calcularJornadas(
        [r('u:1', TipoPonto.entrada, h(8)), r('u:1', TipoPonto.saida, h(12))],
        agora,
        pausaAutomatica: (_, _) => Duration.zero,
      ).single;
      expect(j.pausa, Duration.zero);
      expect(j.pausaAutomatica, isFalse);
    });

    test('a pausa vem da escala de cada pessoa e o CSV assinala-a', () {
      final js = calcularJornadas(
        [
          r('u:1', TipoPonto.entrada, h(8)),
          r('u:1', TipoPonto.saida, h(16, 30)),
          r('u:2', TipoPonto.entrada, h(8), nome: 'Rui'),
          r('u:2', TipoPonto.saida, h(16, 30), nome: 'Rui'),
        ],
        agora,
        pausaAutomatica: (p, _) =>
            p == 'u:1' ? const Duration(minutes: 45) : Duration.zero,
      );
      expect(js.firstWhere((j) => j.pessoa == 'u:1').pausa.inMinutes, 45);
      expect(js.firstWhere((j) => j.pessoa == 'u:2').pausa, Duration.zero);
      final csv = jornadasCsv(js, agora);
      expect(csv, contains('45m (automática)'));
    });
  });
}
