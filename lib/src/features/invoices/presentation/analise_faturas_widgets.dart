import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../application/analise_faturas_controller.dart';
import 'invoice_owner_widgets.dart';

/// Cartões com o progresso do envio e da análise dos ficheiros de faturas
/// (ecrã "Faturas"). Continuam a correr se a pessoa mudar de ecrã.
class AnaliseFaturasPainel extends ConsumerWidget {
  const AnaliseFaturasPainel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trabalhos = ref.watch(analiseFaturasProvider).values.toList();
    if (trabalhos.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final t in trabalhos)
          Card(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            color: t.fase == FaseAnalise.erro
                ? cs.errorContainer
                : (t.fase == FaseAnalise.feita
                      ? cs.primaryContainer
                      : cs.surfaceContainerHigh),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(switch (t.fase) {
                        FaseAnalise.erro => Icons.error_outline,
                        FaseAnalise.feita => Icons.check_circle_outline,
                        _ => Icons.hourglass_top,
                      }, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (!t.ativo)
                        IconButton(
                          tooltip: 'Fechar',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => ref
                              .read(analiseFaturasProvider.notifier)
                              .fechar(t.chave),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(t.texto),
                  if (t.ativo) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: t.progresso),
                    const SizedBox(height: 6),
                    Text(
                      'Podes mudar de ecrã: continua enquanto a app estiver '
                      'aberta.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (t.fase == FaseAnalise.feita || t.fase == FaseAnalise.erro)
                    Wrap(
                      spacing: 8,
                      children: [
                        if (t.fase == FaseAnalise.feita &&
                            t.resumo.itens.length > 1)
                          TextButton(
                            onPressed: () => mostrarResumoAnalise(
                              context,
                              t.titulo,
                              t.resumo,
                            ),
                            child: const Text('Ver o que entrou'),
                          ),
                        if (t.fase == FaseAnalise.feita &&
                            t.totalFaturas == 1 &&
                            t.faturaId != null)
                          TextButton(
                            onPressed: () {
                              ref
                                  .read(analiseFaturasProvider.notifier)
                                  .fechar(t.chave);
                              context.push('${Routes.invoices}/${t.faturaId}');
                            },
                            child: const Text('Rever a fatura'),
                          ),
                        if (t.fase == FaseAnalise.erro && t.faturaId != null)
                          TextButton(
                            onPressed: () => ref
                                .read(analiseFaturasProvider.notifier)
                                .retomar(t.faturaId!, titulo: t.titulo),
                            child: const Text('Continuar / tentar de novo'),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Faixa fina por cima da barra de navegação, em qualquer ecrã, enquanto há um
/// ficheiro de faturas a ser enviado/analisado. Toca para ir às Faturas.
class AnaliseFaturasFaixa extends ConsumerWidget {
  const AnaliseFaturasFaixa({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ativos = ref
        .watch(analiseFaturasProvider)
        .values
        .where((t) => t.ativo)
        .toList();
    if (ativos.isEmpty) return const SizedBox.shrink();
    final t = ativos.first;
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.secondaryContainer,
      child: InkWell(
        onTap: () => context.go(Routes.invoices),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ativos.length > 1
                    ? 'Faturas: ${ativos.length} ficheiros a analisar…'
                    : 'Faturas: ${t.texto}',
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: ativos.length > 1 ? null : t.progresso,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
