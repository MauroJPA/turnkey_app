import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/dashboard/domain/atalhos_inicio.dart';
import 'package:gc_turnkey/src/features/dashboard/domain/tarefa_hoje.dart';

TarefaHoje _t(
  String chave,
  Urgencia u, {
  List<ItemTarefa> itens = const [],
  int quantidade = 0,
}) => TarefaHoje(
  chave: chave,
  icon: Icons.circle,
  titulo: chave,
  urgencia: u,
  rota: '/$chave',
  itens: itens,
  quantidade: quantidade,
);

Future<void> _nada(BuildContext c, dynamic r) async {}

void main() {
  group('separarTarefas', () {
    test(
      'urgente vem primeiro; o resto mantém a ordem; info vai para "saber"',
      () {
        final r = separarTarefas([
          _t('a', Urgencia.atencao),
          _t('b', Urgencia.info),
          _t('c', Urgencia.urgente),
          _t('d', Urgencia.atencao),
          _t('e', Urgencia.urgente),
        ]);
        expect(r.precisa.map((t) => t.chave), ['c', 'e', 'a', 'd']);
        expect(r.saber.map((t) => t.chave), ['b']);
      },
    );

    test('vazio dá listas vazias', () {
      final r = separarTarefas(const []);
      expect(r.precisa, isEmpty);
      expect(r.saber, isEmpty);
    });
  });

  group('TarefaHoje', () {
    test('um item com botão: o botão fica na linha do grupo', () {
      final t = _t(
        'ferias',
        Urgencia.atencao,
        itens: [ItemTarefa('Ana', rotuloAcao: 'Aprovar', acao: _nada)],
      );
      expect(t.acaoDireta, isNotNull);
      expect(t.expansivel, isFalse);
      expect(t.total, 1);
    });

    test('vários itens com botão: o grupo abre', () {
      final t = _t(
        'ferias',
        Urgencia.atencao,
        itens: [
          ItemTarefa('Ana', rotuloAcao: 'Aprovar', acao: _nada),
          ItemTarefa('Rui', rotuloAcao: 'Aprovar', acao: _nada),
        ],
      );
      expect(t.acaoDireta, isNull);
      expect(t.expansivel, isTrue);
      expect(t.total, 2);
      expect(t.subtitulo, 'Ana · Rui');
    });

    test('itens sem botão: só abre a página', () {
      final t = _t(
        'notas',
        Urgencia.atencao,
        itens: [const ItemTarefa('A'), const ItemTarefa('B')],
      );
      expect(t.acaoDireta, isNull);
      expect(t.expansivel, isFalse);
    });

    test('o resumo e a quantidade mandam quando não há itens', () {
      final t = TarefaHoje(
        chave: 'stock',
        icon: Icons.circle,
        titulo: 'Stock baixo',
        urgencia: Urgencia.atencao,
        rota: '/x',
        quantidade: 4,
        resumo: '4 itens abaixo do mínimo',
      );
      expect(t.total, 4);
      expect(t.subtitulo, '4 itens abaixo do mínimo');
    });

    test('o subtítulo mostra no máximo 3 itens', () {
      final t = _t(
        'v',
        Urgencia.atencao,
        itens: [for (final n in 'ABCDE'.split('')) ItemTarefa(n)],
      );
      expect(t.subtitulo, 'A · B · C');
      expect(t.total, 5);
    });
  });

  group('texto do cabeçalho', () {
    test('saudação pela hora', () {
      expect(saudacao(DateTime(2026, 10, 6, 8)), 'Bom dia');
      expect(saudacao(DateTime(2026, 10, 6, 12)), 'Boa tarde');
      expect(saudacao(DateTime(2026, 10, 6, 19, 59)), 'Boa tarde');
      expect(saudacao(DateTime(2026, 10, 6, 20)), 'Boa noite');
    });

    test('data por extenso', () {
      expect(
        dataPorExtenso(DateTime(2026, 10, 6)),
        'terça-feira, 6 de outubro',
      );
      expect(dataPorExtenso(DateTime(2026, 1, 4)), 'domingo, 4 de janeiro');
    });

    test('primeiro nome', () {
      expect(primeiroNome('Ana Silva'), 'Ana');
      expect(primeiroNome('  Rui  '), 'Rui');
      expect(primeiroNome('ana@exemplo.pt'), '');
      expect(primeiroNome(null), '');
    });
  });

  group('atalhosEscolhidos', () {
    bool tudo(String _) => true;

    test('sem escolha: os do costume', () {
      expect(atalhosEscolhidos(null, tudo).map((a) => a.chave), [
        'produzir',
        'assar',
        'contagem',
      ]);
    });

    test('respeita a escolha e a ordem, no máximo 3', () {
      expect(
        atalhosEscolhidos(
          'compras,ponto,haccp,vendas',
          tudo,
        ).map((a) => a.chave),
        ['compras', 'ponto', 'haccp'],
      );
    });

    test('quem escolheu só 1 fica com 1', () {
      expect(atalhosEscolhidos('ponto', tudo).map((a) => a.chave), ['ponto']);
    });

    test(
      'salta o que a pessoa não pode abrir; sem escolha completa com o resto',
      () {
        bool semProducao(String p) => p != 'producao';
        expect(atalhosEscolhidos(null, semProducao).map((a) => a.chave), [
          'contagem',
          'ponto',
          'fatura',
        ]);
        expect(
          atalhosEscolhidos('produzir,ponto', semProducao).map((a) => a.chave),
          ['ponto'],
        );
      },
    );

    test('chaves desconhecidas e repetidas são ignoradas', () {
      expect(atalhosEscolhidos('xpto,ponto,ponto', tudo).map((a) => a.chave), [
        'ponto',
      ]);
    });

    test('sem acesso a nada: lista vazia', () {
      expect(atalhosEscolhidos(null, (_) => false), isEmpty);
    });
  });

  group('diasAtePagamento', () {
    test('hoje é 0; já passou este mês vai para o seguinte', () {
      final hoje = DateTime(2026, 10, 6);
      expect(diasAtePagamento(6, hoje), 0);
      expect(diasAtePagamento(9, hoje), 3);
      expect(diasAtePagamento(1, hoje), 26);
    });
  });
}
