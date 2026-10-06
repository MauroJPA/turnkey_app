import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/app/routes.dart';
import 'package:gc_turnkey/src/features/navigation/domain/destinos_app.dart';
import 'package:gc_turnkey/src/features/navigation/domain/pagina_app.dart';

bool _tudo(String _) => true;

void main() {
  group('normalizarBusca', () {
    test('minúsculas e sem acentos', () {
      expect(normalizarBusca('Férias'), 'ferias');
      expect(normalizarBusca('  Contabilidade '), 'contabilidade');
      expect(normalizarBusca('AÇÚCAR'), 'acucar');
    });
  });

  group('menu "Mais"', () {
    test('cada página está em exatamente um grupo', () {
      final todas = [for (final g in gruposMais) ...g.paginas];
      expect(todas.toSet().length, todas.length, reason: 'repetida num grupo');
      for (final k in todas) {
        expect(paginaPorChave(k), isNotNull, reason: 'chave desconhecida: $k');
      }
      // se faltar uma, o menu mostra-a em "Outras" — mas convém agrupá-la
      expect(paginasSemGrupo(), isEmpty);
    });

    test('as secções apontam para páginas que existem e não se repetem', () {
      final rotas = <String>{};
      for (final d in seccoesApp) {
        expect(paginaPorChave(d.pagina), isNotNull, reason: d.label);
        expect(rotas.add(d.rota), isTrue, reason: 'rota repetida: ${d.rota}');
      }
    });
  });

  group('procurarDestinos', () {
    List<String> r(String q, [bool Function(String)? ok]) => [
      for (final d in procurarDestinos(q, ok ?? _tudo)) d.label,
    ];

    test('encontra sem acentos nem maiúsculas', () {
      expect(r('ferias').first, 'Férias e ausências');
      expect(r('FÉRIAS').first, 'Férias e ausências');
    });

    test('encontra pelo nome da página-mãe e pelas palavras extra', () {
      // a página "Pessoas" empata (a descrição fala em férias): ambas aparecem
      expect(r('pessoas ferias').take(2), contains('Férias e ausências'));
      expect(r('folga'), contains('Férias e ausências'));
      expect(r('manipulador'), contains('Formações e certificados'));
    });

    test('o início do nome ganha ao meio', () {
      // "Ponto" começa por "pon"; "Tabela de revendedores" não
      expect(r('pon').first, 'Ponto');
    });

    test('todas as palavras têm de bater', () {
      expect(r('ferias zzz'), isEmpty);
    });

    test('só mostra o que a pessoa pode abrir', () {
      bool semPessoas(String p) => p != 'pessoas';
      expect(r('ferias', semPessoas), isEmpty);
      expect(r('ponto', semPessoas), isNot(contains('Ponto')));
    });

    test('consulta vazia não devolve nada', () {
      expect(r(''), isEmpty);
      expect(r('   '), isEmpty);
    });

    test('páginas antes das secções quando empatam', () {
      // "Inventário" (página) e "Preços dos ingredientes" (secção): a página
      // vem primeiro porque o nome começa pela consulta
      expect(r('inventario').first, 'Inventário');
    });

    test('respeita o máximo', () {
      expect(
        procurarDestinos('a', _tudo, maximo: 3).length,
        lessThanOrEqualTo(3),
      );
    });
  });

  group('última secção vista', () {
    final inventario = paginaPorChave('inventario')!;
    final producao = paginaPorChave('producao')!;

    test('só as páginas com memória lembram', () {
      expect(deveLembrar('inventario', Routes.inventoryPrecos), isTrue);
      expect(deveLembrar('pessoas', Routes.pessoasFerias), isTrue);
      expect(deveLembrar('financeiro', Routes.relatorios), isTrue);
      expect(deveLembrar('producao', Routes.schedule), isFalse);
    });

    test('rotas de detalhe não se lembram', () {
      expect(deveLembrar('inventario', '/inventario/abc'), isFalse);
      expect(deveLembrar('financeiro', '/financeiro/xpto'), isFalse);
    });

    test('abre na última secção, se válida', () {
      expect(
        rotaAoAbrir(inventario, Routes.inventoryPrecos),
        Routes.inventoryPrecos,
      );
    });

    test('sem memória, ou com rota de outra página, abre a própria página', () {
      expect(rotaAoAbrir(inventario, null), Routes.inventory);
      expect(rotaAoAbrir(inventario, Routes.pessoasFerias), Routes.inventory);
      expect(rotaAoAbrir(inventario, '/lixo'), Routes.inventory);
    });

    test('a Produção abre sempre em Produzir', () {
      expect(rotaAoAbrir(producao, Routes.schedule), Routes.production);
    });

    test('as secções de cada hub com memória estão todas na pesquisa', () {
      for (final r in [
        Routes.painelFinanceiro,
        Routes.dre,
        Routes.custosFixos,
        Routes.numerosMagicos,
        Routes.rentabilidade,
        Routes.tabelaRevendedores,
        Routes.relatorios,
      ]) {
        expect(rotasDaPagina('financeiro'), contains(r));
      }
      for (final r in [
        Routes.pessoasPonto,
        Routes.pessoasFerias,
        Routes.pessoasEscala,
        Routes.pessoasNotas,
        Routes.pessoasFormacoes,
      ]) {
        expect(rotasDaPagina('pessoas'), contains(r));
      }
      for (final r in [
        Routes.inventory,
        Routes.inventoryLimpeza,
        Routes.inventoryMaterial,
        Routes.inventoryEmbalagens,
        Routes.inventoryPrecos,
        Routes.equipamentos,
      ]) {
        expect(rotasDaPagina('inventario'), contains(r));
      }
    });
  });
}
