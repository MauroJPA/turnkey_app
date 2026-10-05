import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/env/env.dart';
import '../../../core/errors/mensagem_amigavel.dart';
import '../../../core/help/help_content.dart';
import '../../../core/printing/print_html.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/help_actions.dart';
import '../../products/presentation/etiqueta_sheet.dart';
import '../../settings/application/empresa_providers.dart';
import '../../tech_sheets/data/tech_sheet_repository.dart';
import '../data/lotes_repository.dart';
import '../domain/lote.dart';
import '../domain/rastreabilidade_html.dart';

/// A página de um lote: o que é, quando se fez, os ingredientes e lotes usados,
/// a etiqueta com QR e a ficha de rastreabilidade. É o que o QR da etiqueta abre.
class LoteDetailScreen extends ConsumerWidget {
  const LoteDetailScreen({super.key, required this.codigo});

  final String codigo;

  static String _d(DateTime? d) => d == null
      ? '—'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _etiqueta(
    BuildContext context,
    WidgetRef ref,
    LoteProducao l,
  ) async {
    try {
      final ficha = await ref
          .read(techSheetRepositoryProvider)
          .getById(l.fichaId);
      if (!context.mounted) return;
      await showEtiquetaSheet(
        context,
        ficha: ficha,
        loteCodigo: l.codigo,
        loteUrl: urlDoLote(Env.pbUrl, l.codigo),
        loteFabrico: l.dataProducao,
      );
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
      }
    }
  }

  Future<void> _ondeFoiUsado(
    BuildContext context,
    WidgetRef ref,
    LoteUsado i,
  ) async {
    try {
      final usos = await ref.read(lotesRepositoryProvider).ondeFoiUsado(i.lote);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Lote ${i.lote} — ${i.nome}'),
          content: SizedBox(
            width: 360,
            child: usos.isEmpty
                ? const Text('Não encontrei lotes de produção com este lote.')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Usado nestes lotes de produção (se houver um '
                        'problema com este lote, são estes os afetados):',
                      ),
                      const SizedBox(height: 8),
                      for (final u in usos)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(u.codigo),
                          subtitle: Text(
                            '${u.fichaNome} · ${_d(u.dataProducao)}',
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            context.go(Routes.lote(u.codigo));
                          },
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(loteProvider(codigo));
    final papel = ref.watch(currentPapelProvider);
    final empresa = ref.watch(currentEmpresaProvider).valueOrNull;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(Routes.productionLotes),
        ),
        title: Text(codigo),
        actions: const [HelpActions(topic: HelpTopic.lotes)],
      ),
      body: AsyncValueView<LoteProducao?>(
        value: async,
        onRetry: () => ref.invalidate(loteProvider(codigo)),
        data: (l) {
          if (l == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Não encontrei este lote.'),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(l.fichaNome, style: tt.headlineSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Chip(label: Text('Produzido ${_d(l.dataProducao)}')),
                  if (l.validade != null)
                    Chip(label: Text('Validade ${_d(l.validade)}')),
                  if (l.quantidade > 0)
                    Chip(label: Text('${l.quantidade.toStringAsFixed(0)} un')),
                  if (l.responsavel.isNotEmpty)
                    Chip(label: Text(l.responsavel)),
                ],
              ),
              if (l.notas.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(l.notas, style: tt.bodyMedium),
                ),
              const SizedBox(height: 16),
              Text('Ingredientes e lotes usados', style: tt.titleMedium),
              if (l.semLote > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${l.semLote} ingrediente(s) sem lote registado.',
                    style: tt.bodySmall?.copyWith(color: cs.error),
                  ),
                ),
              const SizedBox(height: 4),
              for (final i in l.ingredientes)
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  child: ListTile(
                    title: Text(i.nome),
                    subtitle: Text(
                      i.lote.isEmpty
                          ? 'lote não registado'
                          : [
                              'lote ${i.lote}',
                              if (i.fornecedor.isNotEmpty) i.fornecedor,
                              if (i.validade != null) 'val. ${_d(i.validade)}',
                            ].join(' · '),
                      style: TextStyle(color: i.lote.isEmpty ? cs.error : null),
                    ),
                    trailing: i.lote.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Onde mais foi usado este lote?',
                            icon: const Icon(Icons.manage_search),
                            onPressed: () => _ondeFoiUsado(context, ref, i),
                          ),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: l.fichaId.isEmpty
                          ? null
                          : () => _etiqueta(context, ref, l),
                      icon: const Icon(Icons.qr_code_2),
                      label: const Text('Etiqueta com QR'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () => abrirImpressao(
                        'Rastreabilidade ${l.codigo}',
                        rastreabilidadeHtml(l, empresa: empresa?.nome ?? ''),
                        estiloExtra: rastreabilidadeEstilo,
                      ),
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('Ficha'),
                    ),
                  ),
                ],
              ),
              if (papel.canEditConfig)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextButton.icon(
                    onPressed: () async {
                      final ok = await confirmDialog(
                        context,
                        titulo: 'Apagar o lote ${l.codigo}?',
                        mensagem:
                            'Perde-se o registo de rastreabilidade deste lote. '
                            'Só deves apagar se foi criado por engano.',
                        confirmar: 'Apagar',
                        destrutivo: true,
                      );
                      if (!ok) return;
                      try {
                        await ref.read(lotesRepositoryProvider).apagar(l.id);
                        ref.invalidate(lotesRecentesProvider);
                        if (context.mounted) context.go(Routes.productionLotes);
                      } on Object catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(mensagemAmigavel(e))),
                          );
                        }
                      }
                    },
                    icon: Icon(Icons.delete_outline, color: cs.error),
                    label: Text(
                      'Apagar lote',
                      style: TextStyle(color: cs.error),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
