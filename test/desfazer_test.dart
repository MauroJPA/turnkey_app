import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/core/widgets/desfazer.dart';

/// Uma "lista" de 3 itens que esconde os que estão em [ocultosProvider]; cada
/// toque num item apaga-o com "Desfazer".
class _Lista extends ConsumerStatefulWidget {
  const _Lista(this.apagados, {this.falha = false});
  final List<String> apagados;
  final bool falha;

  @override
  ConsumerState<_Lista> createState() => _ListaState();
}

class _ListaState extends ConsumerState<_Lista> {
  String? erro;

  @override
  Widget build(BuildContext context) {
    final ocultos = ref.watch(ocultosProvider);
    return Scaffold(
      body: Column(
        children: [
          for (final id in ['a', 'b', 'c'])
            if (!ocultos.contains(id))
              TextButton(
                onPressed: () => apagarComDesfazer(
                  context,
                  id: id,
                  mensagem: 'Apagado $id',
                  apagar: () async {
                    if (widget.falha) throw StateError('falhou');
                    widget.apagados.add(id);
                  },
                  depois: () {},
                  aoFalhar: (e) => setState(() => erro = 'erro'),
                ),
                child: Text('item $id'),
              ),
          if (erro != null) Text(erro!),
        ],
      ),
    );
  }
}

Widget _app(Widget filho) => ProviderScope(child: MaterialApp(home: filho));

/// Deixa passar o tempo do SnackBar: entra, espera o tempo todo e sai.
Future<void> _passarTempo(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 1)); // acaba de entrar
  await tester.pump(const Duration(seconds: 7)); // acaba o tempo
  await tester.pump(const Duration(seconds: 1)); // sai
  await tester.pump(); // o que vem depois (apagar a sério)
}

void main() {
  testWidgets('o item some já e só se apaga a sério passado o tempo', (
    tester,
  ) async {
    final apagados = <String>[];
    await tester.pumpWidget(_app(_Lista(apagados)));
    await tester.tap(find.text('item b'));
    await tester.pump();
    expect(find.text('item b'), findsNothing);
    expect(find.text('Apagado b'), findsOneWidget);
    expect(find.text('Desfazer'), findsOneWidget);
    expect(apagados, isEmpty);

    await _passarTempo(tester);
    expect(apagados, ['b']);
  });

  testWidgets('Desfazer repõe o item e nada se apaga', (tester) async {
    final apagados = <String>[];
    await tester.pumpWidget(_app(_Lista(apagados)));
    await tester.tap(find.text('item a'));
    await tester.pump();
    expect(find.text('item a'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Desfazer'));
    await _passarTempo(tester);
    expect(find.text('item a'), findsOneWidget);
    expect(apagados, isEmpty);
  });

  testWidgets('apagar outro item confirma o anterior (sem o perder)', (
    tester,
  ) async {
    final apagados = <String>[];
    await tester.pumpWidget(_app(_Lista(apagados)));
    await tester.tap(find.text('item a'));
    await tester.pump();
    await tester.tap(find.text('item b'));
    await _passarTempo(tester);
    await _passarTempo(tester);
    expect(apagados, containsAll(['a', 'b']));
  });

  testWidgets('se o apagar falha, o item volta e há erro', (tester) async {
    final apagados = <String>[];
    await tester.pumpWidget(_app(_Lista(apagados, falha: true)));
    await tester.tap(find.text('item c'));
    await tester.pump();
    await _passarTempo(tester);
    expect(find.text('item c'), findsOneWidget);
    expect(find.text('erro'), findsOneWidget);
    expect(apagados, isEmpty);
  });

  testWidgets('mostrarDesfazer corre a ação de repor ao carregar em Desfazer', (
    tester,
  ) async {
    var reposto = false;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => mostrarDesfazer(
                context,
                mensagem: 'Foi para a lixeira',
                desfazer: () async => reposto = true,
              ),
              child: const Text('mover'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('mover'));
    await tester.pump();
    expect(find.text('Foi para a lixeira'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Desfazer'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(reposto, isTrue);
  });
}
