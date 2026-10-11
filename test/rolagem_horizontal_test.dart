import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/core/widgets/rolagem_horizontal.dart';

Widget _app(ScrollController c, {double largura = 1000}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: largura,
        height: 300,
        child: RolagemHorizontal(
          controller: c,
          passo: 300,
          child: ListView(
            controller: c,
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < 8; i++)
                Container(
                  width: 280,
                  margin: const EdgeInsets.only(right: 10),
                  color: Colors.amber,
                  child: Text('fase $i'),
                ),
            ],
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('o rato arrasta o quadro para o lado', (tester) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = ScrollController();
    addTearDown(c.dispose);
    await tester.pumpWidget(_app(c));
    expect(c.offset, 0);

    final g = await tester.startGesture(
      const Offset(500, 400),
      kind: PointerDeviceKind.mouse,
    );
    // o arrasto só conta depois de passar a folga: dois movimentos
    await g.moveBy(const Offset(-30, 0));
    await g.moveBy(const Offset(-200, 0));
    await g.up();
    await tester.pumpAndSettle();
    expect(c.offset, greaterThan(100));
  });

  testWidgets('setas: só aparecem quando há mais para ver e andam um passo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = ScrollController();
    addTearDown(c.dispose);
    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chevron_left), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(c.offset, 300);
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);

    c.jumpTo(c.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.chevron_right), findsNothing);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(c.offset, lessThan(c.position.maxScrollExtent));
  });

  testWidgets('no telemóvel (ecrã estreito) não há setas', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = ScrollController();
    addTearDown(c.dispose);
    await tester.pumpWidget(_app(c, largura: 400));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.byType(Scrollbar), findsNothing);
  });

  testWidgets('a lista vertical dentro não é arrastada pelo rato', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = ScrollController();
    final v = ScrollController();
    addTearDown(h.dispose);
    addTearDown(v.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1000,
            height: 300,
            child: RolagemHorizontal(
              controller: h,
              child: ListView(
                controller: h,
                scrollDirection: Axis.horizontal,
                children: [
                  SizedBox(
                    width: 300,
                    child: SemArrastoDeRato(
                      child: ListView(
                        controller: v,
                        children: [
                          for (var i = 0; i < 30; i++)
                            SizedBox(height: 40, child: Text('t$i')),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 1500),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final g = await tester.startGesture(
      const Offset(100, 150),
      kind: PointerDeviceKind.mouse,
    );
    await g.moveBy(const Offset(0, -30));
    await g.moveBy(const Offset(0, -120));
    await g.up();
    await tester.pumpAndSettle();
    expect(v.offset, 0);

    final t = await tester.startGesture(const Offset(100, 150));
    await t.moveBy(const Offset(0, -30));
    await t.moveBy(const Offset(0, -120));
    await t.up();
    await tester.pumpAndSettle();
    expect(v.offset, greaterThan(50));
  });
}
