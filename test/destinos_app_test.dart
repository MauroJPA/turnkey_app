import 'package:flutter_test/flutter_test.dart';
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
}
