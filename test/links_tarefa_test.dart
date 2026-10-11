import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/quadros/domain/quadro.dart';
import 'package:gc_turnkey/src/features/quadros/presentation/descricao_com_links.dart';
import 'package:gc_turnkey/src/features/quadros/presentation/links_tarefa.dart';

void main() {
  group('normalizarUrl', () {
    test('aceita http e https e põe https quando falta o esquema', () {
      expect(
        normalizarUrl('https://exemplo.pt/a?b=1'),
        'https://exemplo.pt/a?b=1',
      );
      expect(normalizarUrl('http://exemplo.pt'), 'http://exemplo.pt');
      expect(normalizarUrl('exemplo.pt/pagina'), 'https://exemplo.pt/pagina');
      expect(normalizarUrl('www.exemplo.pt'), 'https://www.exemplo.pt');
      expect(
        normalizarUrl('  exemplo.pt:8080/x  '),
        'https://exemplo.pt:8080/x',
      );
      expect(
        normalizarUrl('http://localhost:8090/x'),
        'http://localhost:8090/x',
      );
    });

    test('recusa o que não é um endereço web', () {
      for (final mau in [
        '',
        '   ',
        'javascript:alert(1)',
        'JAVASCRIPT:alert(1)',
        'mailto:ana@loja.pt',
        'file:///etc/passwd',
        'data:text/html,<b>x</b>',
        'ftp://exemplo.pt/x',
        'duas palavras.pt',
        'semponto',
        'https://',
      ]) {
        expect(normalizarUrl(mau), isNull, reason: mau);
      }
    });
  });

  group('trechosComLinks', () {
    List<String?> urls(String t) => [
      for (final x in trechosComLinks(t))
        if (x.url != null) x.url,
    ];

    test('texto sem endereços é um só bocado simples', () {
      final r = trechosComLinks('Comprar farinha e ovos');
      expect(r.length, 1);
      expect(r.single.url, isNull);
      expect(r.single.texto, 'Comprar farinha e ovos');
    });

    test('marca os endereços e conserva o texto à volta', () {
      final r = trechosComLinks(
        'Ver https://exemplo.pt/x e depois www.loja.pt ok',
      );
      expect(
        [for (final t in r) t.texto].join(),
        'Ver https://exemplo.pt/x e depois www.loja.pt ok',
      );
      expect(urls('Ver https://exemplo.pt/x e depois www.loja.pt ok'), [
        'https://exemplo.pt/x',
        'https://www.loja.pt',
      ]);
    });

    test('a pontuação no fim não entra no link', () {
      expect(urls('Veja https://exemplo.pt.'), ['https://exemplo.pt']);
      expect(urls('(ver https://exemplo.pt/a)'), ['https://exemplo.pt/a']);
      expect(urls('https://exemplo.pt/a_(b)'), ['https://exemplo.pt/a_(b)']);
      expect(urls('Links: https://a.pt, https://b.pt!'), [
        'https://a.pt',
        'https://b.pt',
      ]);
    });

    test('várias linhas e nada de esquemas perigosos', () {
      expect(urls('a\nhttps://a.pt\nb\njavascript:alert(1)'), ['https://a.pt']);
      expect(urls('http://semponto'), isEmpty);
    });
  });

  group('LinkTarefa', () {
    test(
      'lê a lista do servidor, ignora o inválido e dá título ao que não tem',
      () {
        final l = LinkTarefa.listaDeJson([
          {'t': 'Fatura', 'u': 'https://exemplo.pt/f'},
          {'t': '', 'u': 'https://www.loja.pt/x'},
          {'t': 'Mau', 'u': 'javascript:alert(1)'},
          {'t': 'Sem url'},
          'lixo',
        ]);
        expect([for (final x in l) x.titulo], ['Fatura', 'loja.pt']);
        expect(l.first.toJson(), {'t': 'Fatura', 'u': 'https://exemplo.pt/f'});
        expect(LinkTarefa.listaDeJson(null), isEmpty);
        expect(LinkTarefa.listaDeJson('x'), isEmpty);
      },
    );
  });

  group('DescricaoComLinks', () {
    Widget app(
      TextEditingController c, {
      bool enabled = true,
      List<String>? abertos,
    }) => MaterialApp(
      home: Scaffold(
        body: DescricaoComLinks(
          controller: c,
          enabled: enabled,
          hint: 'Detalhes',
          onChanged: () {},
          abrir: (u) async {
            abertos?.add(u);
            return true;
          },
        ),
      ),
    );

    testWidgets('sem endereços é o campo de texto normal', (tester) async {
      final c = TextEditingController(text: 'só texto');
      addTearDown(c.dispose);
      await tester.pumpWidget(app(c));
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('com endereço mostra o texto com o link clicável', (
      tester,
    ) async {
      final abertos = <String>[];
      final c = TextEditingController(text: 'Ver https://exemplo.pt/x agora');
      addTearDown(c.dispose);
      await tester.pumpWidget(app(c, abertos: abertos));
      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('Ver ', findRichText: true), findsOneWidget);

      // toca no link: procura o bocado sublinhado e aciona o seu toque
      final rich = tester
          .widgetList<RichText>(find.byType(RichText))
          .firstWhere((r) => r.text.toPlainText().contains('exemplo.pt'));
      rich.text.visitChildren((s) {
        if (s is TextSpan && s.text == 'https://exemplo.pt/x') {
          (s.recognizer! as dynamic).onTap();
          return false;
        }
        return true;
      });
      await tester.pump();
      expect(abertos, ['https://exemplo.pt/x']);
    });

    testWidgets('tocar no lápis passa a editar', (tester) async {
      final c = TextEditingController(text: 'https://exemplo.pt');
      addTearDown(c.dispose);
      await tester.pumpWidget(app(c));
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('sem permissão de editar não há lápis', (tester) async {
      final c = TextEditingController(text: 'https://exemplo.pt');
      addTearDown(c.dispose);
      await tester.pumpWidget(app(c, enabled: false));
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('LinksTarefa', () {
    Future<List<LinkTarefa>> montar(
      WidgetTester tester,
      List<LinkTarefa> links, {
      bool pode = true,
      List<String>? abertos,
    }) async {
      var atual = links;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => LinksTarefa(
                links: atual,
                pode: pode,
                onMudou: (l) => setState(() => atual = l),
                abrir: (u) async {
                  abertos?.add(u);
                  return true;
                },
              ),
            ),
          ),
        ),
      );
      return atual;
    }

    testWidgets('cada link é um botão com o título que abre o endereço', (
      tester,
    ) async {
      final abertos = <String>[];
      await montar(tester, const [
        LinkTarefa('Fatura', 'https://exemplo.pt/f'),
        LinkTarefa('Menu', 'https://loja.pt'),
      ], abertos: abertos);
      expect(find.text('Fatura'), findsOneWidget);
      await tester.tap(find.text('Menu'));
      await tester.pump();
      expect(abertos, ['https://loja.pt']);
    });

    testWidgets('junta um link novo com título e endereço', (tester) async {
      await montar(tester, const []);
      await tester.tap(find.text('Link'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'O que é'),
        'Fornecedor',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Endereço'),
        'forn.pt/catalogo',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Fornecedor'), findsOneWidget);
    });

    testWidgets('endereço inválido não guarda e explica', (tester) async {
      await montar(tester, const []);
      await tester.tap(find.text('Link'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Endereço'),
        'javascript:alert(1)',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('endereço válido'), findsOneWidget);
    });

    testWidgets('sem título usa o nome do sítio', (tester) async {
      await montar(tester, const []);
      await tester.tap(find.text('Link'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Endereço'),
        'https://www.loja.pt/x',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('loja.pt'), findsOneWidget);
    });

    testWidgets('o × tira o link com Desfazer', (tester) async {
      await montar(tester, const [
        LinkTarefa('Fatura', 'https://exemplo.pt/f'),
      ]);
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();
      expect(find.text('Fatura'), findsNothing);
      expect(find.text('Desfazer'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1)); // acaba de entrar
      await tester.tap(find.text('Desfazer'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.text('Fatura'), findsOneWidget);
    });

    testWidgets('sem permissão não há "Link" nem ×', (tester) async {
      await montar(tester, const [
        LinkTarefa('Fatura', 'https://exemplo.pt/f'),
      ], pode: false);
      expect(find.text('Link'), findsNothing);
      expect(find.byIcon(Icons.clear), findsNothing);
      expect(find.text('Fatura'), findsOneWidget);
    });
  });
}
