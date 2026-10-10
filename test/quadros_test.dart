import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/quadros/domain/quadro.dart';

Tarefa _t(
  String id, {
  String coluna = 'c1',
  double ordem = 0,
  String titulo = 'Tarefa',
  List<String> resp = const [],
  DateTime? prazo,
  List<String> etiquetas = const [],
  bool arquivada = false,
  DateTime? criada,
}) => Tarefa(
  id: id,
  quadroId: 'q',
  colunaId: coluna,
  titulo: titulo,
  ordem: ordem,
  responsaveis: resp,
  prazo: prazo,
  etiquetas: etiquetas,
  arquivada: arquivada,
  criada: criada ?? DateTime(2026, 10, 1),
);

void main() {
  final hoje = DateTime(2026, 10, 10, 15);

  group('ordem dos cartões', () {
    test('tarefasDaColuna: só da fase, por ordem e depois as mais antigas', () {
      final l = tarefasDaColuna([
        _t('a', ordem: 2000),
        _t('b', coluna: 'c2'),
        _t('c', ordem: 1000, criada: DateTime(2026, 10, 2)),
        _t('d', ordem: 1000, criada: DateTime(2026, 10, 1)),
      ], 'c1');
      expect(l.map((t) => t.id), ['d', 'c', 'a']);
    });

    test('ordemNaPosicao: início, meio, fim e fase vazia', () {
      final col = [_t('a', ordem: 1000), _t('b', ordem: 2000)];
      expect(ordemNaPosicao(const [], 0), 1000);
      expect(ordemNaPosicao(col, 0), 0);
      expect(ordemNaPosicao(col, 1), 1500);
      expect(ordemNaPosicao(col, 2), 3000);
      expect(ordemNaPosicao(col, 99), 3000);
    });

    test('mover dentro da mesma fase ignora o próprio cartão', () {
      final col = [
        _t('a', ordem: 1000),
        _t('b', ordem: 2000),
        _t('c', ordem: 3000),
      ];
      // "a" para o fim: fica depois do "c"
      expect(ordemNaPosicao(col, 2, movido: 'a'), 4000);
      // "c" para o início
      expect(ordemNaPosicao(col, 0, movido: 'c'), 0);
      final nova = ordemNaPosicao(col, 1, movido: 'a'); // entre b e c
      expect(nova, greaterThan(2000));
      expect(nova, lessThan(3000));
    });

    test('ordemAoLargar: como se vê no ecrã, também na mesma fase', () {
      final col = [
        _t('a', ordem: 1000),
        _t('b', ordem: 2000),
        _t('c', ordem: 3000),
      ];
      List<String> depois(String id, int antesDe) {
        final o = ordemAoLargar(col, antesDe, id);
        final nova = [
          for (final t in col) t.id == id ? t.copyWith(ordem: o) : t,
        ];
        return tarefasDaColuna(nova, 'c1').map((t) => t.id).toList();
      }

      expect(depois('a', 2), ['b', 'a', 'c']); // largar "a" antes do "c"
      expect(depois('a', 3), ['b', 'c', 'a']); // no fim
      expect(depois('c', 0), ['c', 'a', 'b']); // no início
      expect(depois('c', 1), ['a', 'c', 'b']); // antes do "b"
      expect(depois('b', 1), ['a', 'b', 'c']); // no mesmo sítio
      // de outra fase
      expect(ordemAoLargar(col, 1, 'x'), 1500);
    });

    test('ordemNoFim', () {
      expect(ordemNoFim(const []), 1000);
      expect(ordemNoFim(const [500, 3000, 1000]), 4000);
    });
  });

  group('prazos', () {
    test('atrasada / para hoje, e nunca numa fase feita', () {
      final ontem = _t('a', prazo: DateTime(2026, 10, 9));
      final hj = _t('b', prazo: DateTime(2026, 10, 10));
      final sem = _t('c');
      expect(ontem.atrasada(hoje, feita: false), isTrue);
      expect(ontem.atrasada(hoje, feita: true), isFalse);
      expect(hj.atrasada(hoje, feita: false), isFalse);
      expect(hj.paraHoje(hoje, feita: false), isTrue);
      expect(hj.paraHoje(hoje, feita: true), isFalse);
      expect(sem.atrasada(hoje, feita: false), isFalse);
    });

    test('prazoTexto', () {
      expect(prazoTexto(DateTime(2026, 10, 10), hoje), 'hoje');
      expect(prazoTexto(DateTime(2026, 10, 11), hoje), 'amanhã');
      expect(prazoTexto(DateTime(2026, 10, 9), hoje), 'ontem');
      expect(prazoTexto(DateTime(2026, 10, 7), hoje), 'há 3 dias');
      expect(prazoTexto(DateTime(2026, 10, 13), hoje), 'em 3 dias');
      expect(prazoTexto(DateTime(2026, 10, 20), hoje), '20/10');
      expect(prazoTexto(DateTime(2027, 1, 2), hoje), '2/1/2027');
    });
  });

  group('lista de verificação', () {
    test('lê JSON tolerante e conta os feitos', () {
      final itens = ItemChecklist.listaDeJson([
        {'t': 'Farinha', 'f': true},
        {'t': 'Açúcar'},
        {'t': '   '},
        'lixo',
        {'f': true},
      ]);
      expect(itens.map((i) => i.texto), ['Farinha', 'Açúcar']);
      final t = _t('a').copyWith(checklist: itens);
      expect(t.checklistFeitos, 1);
      expect(t.temChecklist, isTrue);
      expect(itens.first.toJson(), {'t': 'Farinha', 'f': true});
      expect(ItemChecklist.listaDeJson(null), isEmpty);
    });
  });

  group('filtros', () {
    final tarefas = [
      _t('minha', resp: ['u1'], titulo: 'Limpar forno'),
      _t(
        'outra',
        resp: ['u2'],
        titulo: 'Encomendar ovos',
        etiquetas: ['Compras'],
      ),
      _t('atrasada', prazo: DateTime(2026, 10, 1), titulo: 'Pintar'),
      _t(
        'feita',
        coluna: 'fim',
        prazo: DateTime(2026, 10, 1),
        titulo: 'Já foi',
      ),
      _t('arq', arquivada: true, resp: ['u1']),
    ];

    List<String> ids(FiltroTarefas f, {String busca = ''}) => filtrarTarefas(
      tarefas,
      filtro: f,
      uid: 'u1',
      colunasFeitas: {'fim'},
      comMencaoPorLer: {'outra'},
      nomes: {'u2': 'João Ação'},
      busca: busca,
      hoje: hoje,
    ).map((t) => t.id).toList();

    test('rápidos', () {
      expect(ids(FiltroTarefas.todas), ['minha', 'outra', 'atrasada', 'feita']);
      expect(ids(FiltroTarefas.minhas), ['minha']);
      expect(ids(FiltroTarefas.mencoes), ['outra']);
      expect(ids(FiltroTarefas.atrasadas), ['atrasada']);
    });

    test('pesquisa por título, etiqueta e responsável, sem acentos', () {
      expect(ids(FiltroTarefas.todas, busca: 'forno'), ['minha']);
      expect(ids(FiltroTarefas.todas, busca: 'compras'), ['outra']);
      expect(ids(FiltroTarefas.todas, busca: 'joao acao'), ['outra']);
    });
  });

  group('menções', () {
    const pessoas = [
      PessoaEquipa('ana', 'Ana'),
      PessoaEquipa('anas', 'Ana Silva'),
      PessoaEquipa('joao', 'João Pereira'),
    ];

    test(
      'mencoesNoTexto: nome completo ganha, primeiro nome e sem acentos',
      () {
        expect(mencoesNoTexto('@Ana Silva podes ver?', pessoas), ['anas']);
        expect(mencoesNoTexto('obrigado @ana!', pessoas), ['ana']);
        expect(mencoesNoTexto('@joao e @João Pereira', pessoas), ['joao']);
        expect(mencoesNoTexto('email ana@ana.pt', pessoas), isEmpty);
        expect(mencoesNoTexto('(@Ana)', pessoas), ['ana']);
        expect(mencoesNoTexto('@Anabela não existe', pessoas), isEmpty);
        expect(mencoesNoTexto('sem menções', pessoas), isEmpty);
      },
    );

    test('mencaoAEscrever: só a palavra com @ no cursor', () {
      expect(mencaoAEscrever('olá @an', 7), 'an');
      expect(mencaoAEscrever('@', 1), '');
      expect(mencaoAEscrever('ana@x', 5), isNull);
      expect(mencaoAEscrever('olá', 3), isNull);
      expect(mencaoAEscrever('@Ana Silva diz que', 18), isNull);
    });

    test('sugerirPessoas e inserirMencao', () {
      expect(sugerirPessoas(pessoas, 'an').map((p) => p.id), ['ana', 'anas']);
      expect(sugerirPessoas(pessoas, 'per').map((p) => p.id), ['joao']);
      final r = inserirMencao('olá @jo resto', 7, pessoas[2]);
      expect(r.texto, 'olá @João Pereira  resto');
      expect(r.cursor, 'olá @João Pereira '.length);
    });

    test('mencaoPorLer', () {
      final c = ComentarioTarefa(
        id: 'c',
        tarefaId: 't',
        texto: 'x',
        criado: hoje,
        mencoes: const ['u1', 'u2'],
        lidaPor: const ['u2'],
      );
      expect(c.mencaoPorLer('u1'), isTrue);
      expect(c.mencaoPorLer('u2'), isFalse);
      expect(c.mencaoPorLer('u3'), isFalse);
      expect(c.mencaoPorLer(''), isFalse);
    });
  });

  test('iniciais, etiquetas e cores', () {
    expect(const PessoaEquipa('a', 'Ana Maria Silva').iniciais, 'AS');
    expect(const PessoaEquipa('a', 'ana').iniciais, 'A');
    expect(const PessoaEquipa('a', '  ').iniciais, '?');
    expect(corEtiqueta('Urgente'), corEtiqueta(' urgente '));
    expect(corEtiqueta('x'), inInclusiveRange(0, 7));
    expect(
      etiquetasUsadas([
        _t('a', etiquetas: ['Loja', 'urgente']),
        _t('b', etiquetas: ['Urgente', 'Ação']),
      ]),
      ['Ação', 'Loja', 'urgente'],
    );
  });
}
