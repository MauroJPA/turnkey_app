import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/help_actions.dart';
import '../../ingredients/application/ingredients_providers.dart';
import '../../ingredients/domain/ingredient.dart';
import '../../tech_sheets/application/tech_sheets_providers.dart';
import '../../tech_sheets/domain/tech_sheet.dart';
import '../domain/saude_dados.dart';
import '../../../app/theme/cores_estado.dart';

/// A análise com o que falta preencher.
final saudeDadosProvider = FutureProvider.autoDispose<RelatorioSaude>((
  ref,
) async {
  final List<FichaTecnica> fichas = await ref.watch(
    fichasListProvider(false).future,
  );
  final List<Ingrediente> ingredientes = await ref.watch(
    ingredientsListProvider(false).future,
  );
  return analisarDados(fichas: fichas, ingredientes: ingredientes);
});

/// "Saúde dos dados": o que falta nas fichas e nos ingredientes para a
/// rentabilidade, a previsão e as etiquetas ficarem certas.
class SaudeDadosScreen extends ConsumerWidget {
  const SaudeDadosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.settings),
        ),
        title: const Text('Saúde dos dados'),
        actions: const [HelpActions(topic: HelpTopic.saudeDados)],
      ),
      body: AsyncValueView<RelatorioSaude>(
        value: ref.watch(saudeDadosProvider),
        onRetry: () => ref.invalidate(saudeDadosProvider),
        data: (r) {
          final cor = r.essenciais == 0
              ? cs.sucesso
              : (r.completoPct >= 80 ? cs.aviso : cs.error);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(saudeDadosProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: r.completoPct / 100,
                                strokeWidth: 6,
                                color: cor,
                                backgroundColor: cs.surfaceContainerHighest,
                              ),
                              Text(
                                '${r.completoPct.toStringAsFixed(0)}%',
                                style: tt.titleSmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.problemas.isEmpty
                                    ? 'Tudo preenchido'
                                    : '${r.problemas.length} por preencher',
                                style: tt.titleMedium,
                              ),
                              Text(
                                r.problemas.isEmpty
                                    ? 'A rentabilidade, a previsão e as etiquetas têm os dados que precisam.'
                                    : 'Em ${r.fichas} produtos e ${r.ingredientes} ingredientes. '
                                          '${r.essenciais > 0 ? 'Resolve primeiro os de preços e custos.' : 'Nada de preços ou custos em falta.'}',
                                style: tt.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                for (final t in TipoProblema.values)
                  if (r.de(t).isNotEmpty)
                    Card(
                      margin: const EdgeInsets.only(top: 8),
                      child: ExpansionTile(
                        shape: const Border(),
                        collapsedShape: const Border(),
                        initiallyExpanded: t.essencial,
                        leading: Icon(
                          t.eFicha
                              ? Icons.receipt_long_outlined
                              : Icons.inventory_2_outlined,
                          color: t.essencial ? cs.error : null,
                        ),
                        title: Text('${t.titulo} (${r.de(t).length})'),
                        subtitle: Text(t.consequencia, style: tt.bodySmall),
                        children: [
                          for (final p in r.de(t))
                            ListTile(
                              dense: true,
                              title: Text(p.nome),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.go(
                                t.eFicha
                                    ? '${Routes.techSheets}/${p.id}'
                                    : Routes.inventory,
                              ),
                            ),
                        ],
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}
