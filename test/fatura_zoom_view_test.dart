import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/invoices/presentation/fatura_zoom_view.dart';

Widget _app({VoidCallback? telaCheia}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: 360,
      height: 400,
      child: FaturaZoomView(
        url: 'http://localhost/nao-existe.jpg',
        aoTelaCheia: telaCheia,
      ),
    ),
  ),
);

double _escala(WidgetTester t) => t
    .widget<InteractiveViewer>(find.byType(InteractiveViewer))
    .transformationController!
    .value
    .getMaxScaleOnAxis();

void main() {
  testWidgets('começa sem zoom e os botões ampliam e reduzem', (t) async {
    await t.pumpWidget(_app());
    expect(_escala(t), 1);

    await t.tap(find.byKey(const ValueKey('fatura-zoom-mais')));
    await t.pump();
    expect(_escala(t), closeTo(1.6, 0.01));

    await t.tap(find.byKey(const ValueKey('fatura-zoom-mais')));
    await t.pump();
    expect(_escala(t), closeTo(2.56, 0.01));

    await t.tap(find.byKey(const ValueKey('fatura-zoom-menos')));
    await t.pump();
    expect(_escala(t), closeTo(1.6, 0.01));

    // reduzir até ao fim repõe a imagem inteira
    await t.tap(find.byKey(const ValueKey('fatura-zoom-menos')));
    await t.pump();
    expect(_escala(t), 1);
  });

  testWidgets('o zoom nunca passa de 8×', (t) async {
    await t.pumpWidget(_app());
    for (var i = 0; i < 10; i++) {
      await t.tap(find.byKey(const ValueKey('fatura-zoom-mais')));
      await t.pump();
    }
    expect(_escala(t), closeTo(8, 0.01));
  });

  testWidgets('duplo toque amplia e volta a repor', (t) async {
    await t.pumpWidget(_app());
    final centro = t.getCenter(find.byType(InteractiveViewer));
    await t.tapAt(centro);
    await t.pump(const Duration(milliseconds: 50));
    await t.tapAt(centro);
    await t.pumpAndSettle();
    expect(_escala(t), closeTo(2.5, 0.01));

    await t.tapAt(centro);
    await t.pump(const Duration(milliseconds: 50));
    await t.tapAt(centro);
    await t.pumpAndSettle();
    expect(_escala(t), 1);
  });

  testWidgets('o botão de ecrã inteiro só aparece quando há ação', (t) async {
    await t.pumpWidget(_app());
    expect(find.byKey(const ValueKey('fatura-tela-cheia')), findsNothing);

    var aberto = 0;
    await t.pumpWidget(_app(telaCheia: () => aberto++));
    await t.tap(find.byKey(const ValueKey('fatura-tela-cheia')));
    expect(aberto, 1);
  });
}
