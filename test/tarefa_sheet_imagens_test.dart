import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/core/auth/current_user.dart';
import 'package:gc_turnkey/src/core/auth/permissions.dart';
import 'package:gc_turnkey/src/features/quadros/application/quadros_providers.dart';
import 'package:gc_turnkey/src/features/quadros/data/quadros_repository.dart';
import 'package:gc_turnkey/src/features/quadros/domain/quadro.dart';
import 'package:gc_turnkey/src/features/quadros/presentation/imagens_tarefa.dart';
import 'package:gc_turnkey/src/features/quadros/presentation/tarefa_sheet.dart';
import 'package:pocketbase/pocketbase.dart';

/// A folha da tarefa tem de construir SEMPRE a secção das imagens: é ela que
/// escuta o Ctrl+V (colar). Com uma lista "preguiçosa", numa janela baixa a
/// secção ficava fora do ecrã, por construir, e colar uma imagem não fazia nada.
void main() {
  Widget app() => ProviderScope(
    overrides: [
      quadrosRepositoryProvider.overrideWithValue(
        QuadrosRepository(PocketBase('http://127.0.0.1:1'), 'emp'),
      ),
      currentPapelProvider.overrideWithValue(Papel.admin),
      pessoasEquipaProvider.overrideWithValue(const []),
      comentariosTarefaProvider.overrideWith((ref, id) async => const []),
      tokenImagensProvider.overrideWith((ref) async => 'token'),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: TarefaSheet(
          tarefa: Tarefa(
            id: 't1',
            quadroId: 'q1',
            colunaId: 'c1',
            titulo: 'Montra',
            criada: DateTime(2026, 10, 10),
          ),
          colunas: const [
            ColunaQuadro(id: 'c1', quadroId: 'q1', nome: 'A fazer'),
          ],
          todas: const [],
        ),
      ),
    ),
  );

  for (final altura in [900.0, 420.0]) {
    testWidgets(
      'a secção das imagens existe com a janela a ${altura.toInt()} px',
      (tester) async {
        tester.view.physicalSize = Size(520, altura);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(app());
        await tester.pump(const Duration(milliseconds: 50));
        expect(
          find.byType(ImagensTarefa, skipOffstage: false),
          findsOneWidget,
          reason: 'sem ela, Ctrl+V não junta imagens',
        );
      },
    );
  }
}
