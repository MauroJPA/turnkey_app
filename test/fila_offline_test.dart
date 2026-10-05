import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/haccp/domain/haccp.dart';
import 'package:gc_turnkey/src/features/quiosque/domain/colaborador.dart';
import 'package:gc_turnkey/src/features/quiosque/domain/fila_offline.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  final quando = DateTime(2026, 10, 7, 9, 30);

  RegistoPendente reg({String id = 'abcdefghij12345', String c = 'c1'}) =>
      RegistoPendente(
        id: id,
        controloId: c,
        dataHora: quando,
        conforme: false,
        valor: 7.5,
        responsavel: 'Ana',
        notas: 'n',
        acaoCorretiva: 'a',
        tentativas: 2,
      );

  test('ids novos têm o formato do PocketBase', () {
    final id = novoIdPb(math.Random(1));
    expect(id, hasLength(15));
    expect(idPbValido(id), isTrue);
    expect(novoIdPb(), isNot(novoIdPb()));
    expect(idPbValido('ABC'), isFalse);
    expect(idPbValido('abcdefghij1234!'), isFalse);
  });

  test('a fila guarda-se e lê-se sem perder nada', () {
    final lida = lerFila(codificarFila([reg(), reg(id: 'zyxwvutsrq54321')]));
    expect(lida, hasLength(2));
    final r = lida.first;
    expect(r.id, 'abcdefghij12345');
    expect(r.controloId, 'c1');
    expect(r.dataHora.isAtSameMomentAs(quando), isTrue);
    expect(r.conforme, isFalse);
    expect(r.valor, 7.5);
    expect(r.responsavel, 'Ana');
    expect(r.acaoCorretiva, 'a');
    expect(r.tentativas, 2);
    expect(r.maisUmaTentativa().tentativas, 3);
  });

  test('a fila ignora lixo e entradas estragadas', () {
    expect(lerFila(null), isEmpty);
    expect(lerFila(''), isEmpty);
    expect(lerFila('isto não é json'), isEmpty);
    expect(lerFila('{"a":1}'), isEmpty);
    expect(
      lerFila(
        '[{"id":"curto","controlo":"c","dataHora":"2026-10-07T09:00:00Z"},'
        '{"id":"abcdefghij12345","controlo":"","dataHora":"2026-10-07T09:00:00Z"},'
        '{"id":"abcdefghij12345","controlo":"c","dataHora":"xx"},'
        '{"id":"abcdefghij12345","controlo":"c","dataHora":"2026-10-07T09:00:00Z"}]',
      ),
      hasLength(1),
    );
  });

  test('que erros são "sem ligação"', () {
    expect(eErroDeLigacao(ClientException(statusCode: 0)), isTrue);
    expect(eErroDeLigacao(ClientException(statusCode: 503)), isTrue);
    expect(eErroDeLigacao(ClientException(statusCode: 502)), isTrue);
    expect(eErroDeLigacao(ClientException(statusCode: 504)), isTrue);
    // falha de rede no PocketBase vem marcada como "abort"
    expect(eErroDeLigacao(ClientException(isAbort: true)), isTrue);
    expect(
      eErroDeLigacao(ClientException(originalError: StateError('closed'))),
      isFalse,
    );
    expect(eErroDeLigacao(ClientException(statusCode: 400)), isFalse);
    expect(eErroDeLigacao(ClientException(statusCode: 404)), isFalse);
    expect(eErroDeLigacao(Exception('x')), isFalse);
    expect(eErroDeSessao(ClientException(statusCode: 401)), isTrue);
    expect(eErroDeSessao(ClientException(statusCode: 403)), isTrue);
    expect(eErroDeSessao(ClientException(statusCode: 400)), isFalse);
  });

  test('reenviar um id que já existe conta como enviado', () {
    expect(
      eIdJaExiste(
        ClientException(
          statusCode: 400,
          response: {
            'data': {
              'id': {'code': 'validation_pk_invalid'},
            },
          },
        ),
      ),
      isTrue,
    );
    expect(
      eIdJaExiste(
        ClientException(
          statusCode: 400,
          response: {
            'data': {
              'controlo': {'code': 'validation_required'},
            },
          },
        ),
      ),
      isFalse,
    );
    expect(eIdJaExiste(ClientException(statusCode: 500)), isFalse);
  });

  group('cache das tarefas e das pessoas', () {
    const c = ControloHaccp(
      id: 'c1',
      nome: 'Frigorífico',
      tipo: TipoControlo.temperatura,
      vezesPorDia: 2,
      limiteMin: 0,
      limiteMax: 5,
      unidade: '°C',
      local: 'Cozinha',
      instrucoes: 'Medir ao centro',
      ordem: 3,
    );

    test('ida e volta de um controlo', () {
      final r = controloDeJson(controloParaJson(c))!;
      expect(r.id, 'c1');
      expect(r.nome, 'Frigorífico');
      expect(r.tipo, TipoControlo.temperatura);
      expect(r.vezesPorDia, 2);
      expect(r.limiteMin, 0);
      expect(r.limiteMax, 5);
      expect(r.limitesTexto, '0 a 5 °C');
      expect(r.instrucoes, 'Medir ao centro');
      expect(r.ordem, 3);
      expect(r.esperadosPorDia, 2);
      expect(controloDeJson('x'), isNull);
      expect(controloDeJson({'nome': 'sem id'}), isNull);
    });

    test('ida e volta dos estados', () {
      final lidos = lerEstados(
        codificarEstados([
          const StatusControlo(
            controlo: c,
            estado: EstadoControlo.pendenteHoje,
            feitosHoje: 1,
            esperadosHoje: 2,
          ),
        ]),
      );
      expect(lidos, hasLength(1));
      expect(lidos.single.estado, EstadoControlo.pendenteHoje);
      expect(lidos.single.feitosHoje, 1);
      expect(lidos.single.esperadosHoje, 2);
      expect(lidos.single.controlo.nome, 'Frigorífico');
      expect(lerEstados('lixo'), isEmpty);
      expect(lerEstados(null), isEmpty);
    });

    test('ida e volta das pessoas (com o cartão)', () {
      final lidas = lerPessoas(
        codificarPessoas(const [
          Colaborador(id: 'p1', nome: 'Ana', nfcUid: '04A1B2C3', userId: 'u1'),
          Colaborador(id: 'p2', nome: 'Rui'),
        ]),
      );
      expect(lidas.map((p) => p.nome), ['Ana', 'Rui']);
      expect(colaboradorDoCartao('04:a1:b2:c3', lidas)?.nome, 'Ana');
      expect(lidas.first.daEquipa, isTrue);
      expect(lerPessoas('[1,2]'), isEmpty);
    });
  });

  group('comPendentes', () {
    StatusControlo status(
      String id, {
      EstadoControlo e = EstadoControlo.pendenteHoje,
      int feitos = 0,
      int esperados = 1,
    }) => StatusControlo(
      controlo: ControloHaccp(id: id, nome: id, vezesPorDia: esperados),
      estado: e,
      feitosHoje: feitos,
      esperadosHoje: esperados,
      diasAtraso: e == EstadoControlo.atrasado ? 3 : 0,
    );

    final agora = DateTime(2026, 10, 7, 12);

    test('sem pendentes devolve igual', () {
      final base = [status('a')];
      expect(identical(comPendentes(base, const [], agora), base), isTrue);
    });

    test('um registo pendente faz a tarefa passar a feita', () {
      final r = comPendentes([status('a'), status('b')], [reg(c: 'a')], agora);
      expect(r[0].estado, EstadoControlo.emDia);
      expect(r[0].feitosHoje, 1);
      expect(r[1].estado, EstadoControlo.pendenteHoje);
    });

    test('tarefa atrasada fica em dia com o registo', () {
      final r = comPendentes(
        [status('a', e: EstadoControlo.atrasado)],
        [reg(c: 'a')],
        agora,
      ).single;
      expect(r.estado, EstadoControlo.emDia);
      expect(r.diasAtraso, 0);
    });

    test('tarefas com várias vezes por dia contam até ao esperado', () {
      final um = comPendentes(
        [status('a', esperados: 3, feitos: 1)],
        [reg(c: 'a')],
        agora,
      ).single;
      expect(um.feitosHoje, 2);
      expect(um.estado, EstadoControlo.pendenteHoje);
      final tres = comPendentes(
        [status('a', esperados: 3, feitos: 1)],
        [reg(c: 'a'), reg(c: 'a', id: 'zyxwvutsrq54321')],
        agora,
      ).single;
      expect(tres.feitosHoje, 3);
      expect(tres.estado, EstadoControlo.emDia);
    });

    test('registos de outros dias não contam; ocasionais ficam ocasionais', () {
      final ontem = RegistoPendente(
        id: 'abcdefghij12345',
        controloId: 'a',
        dataHora: DateTime(2026, 10, 6, 20),
        conforme: true,
      );
      expect(
        comPendentes([status('a')], [ontem], agora).single.estado,
        EstadoControlo.pendenteHoje,
      );
      expect(
        comPendentes(
          [status('a', e: EstadoControlo.ocasional)],
          [reg(c: 'a')],
          agora,
        ).single.estado,
        EstadoControlo.ocasional,
      );
    });
  });
}
