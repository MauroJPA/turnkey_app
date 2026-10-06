import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/core/formatting/money_provider.dart';
import 'package:gc_turnkey/src/features/production/domain/plano_pronto.dart';
import 'package:gc_turnkey/src/features/production/presentation/plano_pronto_sheet.dart';

Widget _app(
  ResumoPlanoPronto resumo,
  Future<ResumoPlanoPronto> Function() preparar,
) => ProviderScope(
  overrides: [
    moneyFormatProvider.overrideWithValue((v) => '€${v.toStringAsFixed(2)}'),
  ],
  child: MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => mostrarPlanoPronto(
              context,
              planoId: 'p1',
              resumo: resumo,
              preparar: preparar,
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('mostra o agendado e o que falta comprar', (tester) async {
    await tester.pumpWidget(
      _app(
        const ResumoPlanoPronto(
          rotulo: 'amanhã',
          produtos: 3,
          compras: EstadoCompras.faltam,
          aComprar: 2,
          custo: 12.5,
          nomes: ['Manteiga', 'Farinha'],
        ),
        () async => throw StateError('não devia preparar'),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Plano de amanhã pronto'), findsOneWidget);
    expect(find.text('3 produtos para amanhã'), findsOneWidget);
    expect(find.text('Faltam 2 ingredientes (≈ €12.50)'), findsOneWidget);
    expect(find.text('Manteiga · Farinha'), findsOneWidget);
    expect(find.text('Ver produção'), findsOneWidget);
    expect(find.text('Abrir compras'), findsOneWidget);
  });

  testWidgets('compras desligadas: "Preparar agora" refaz o resumo', (
    tester,
  ) async {
    const base = ResumoPlanoPronto(rotulo: 'hoje', produtos: 1);
    var chamadas = 0;
    await tester.pumpWidget(
      _app(base, () async {
        chamadas++;
        return base.comCompras(compras: EstadoCompras.chega);
      }),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('A lista de compras não foi preparada.'), findsOneWidget);
    await tester.tap(find.text('Preparar agora'));
    await tester.pumpAndSettle();

    expect(chamadas, 1);
    expect(find.text('O stock chega: não falta comprar nada.'), findsOneWidget);
    expect(find.text('Preparar agora'), findsNothing);
    expect(find.text('Abrir compras'), findsNothing);
  });
}
