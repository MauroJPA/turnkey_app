import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/formatting/dates.dart';
import '../../../core/formatting/money_provider.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/help_actions.dart';
import '../../../core/widgets/history_sheet.dart';
import '../../settings/application/empresa_providers.dart';
import '../application/invoice_providers.dart';
import '../domain/fatura.dart';
import 'contabilidade_sheet.dart';

class InvoicesScreen extends ConsumerWidget {
  const InvoicesScreen({super.key});

  bool _podeEditar(WidgetRef ref) =>
      ref.read(currentPapelProvider).canEditBusiness;

  Future<void> _nova(BuildContext context, WidgetRef ref) async {
    final tipo = await showDialog<FaturaTipo>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('O que vais carregar?'),
        children: [
          for (final t in FaturaTipo.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, t),
              child: ListTile(
                leading: Icon(t == FaturaTipo.fatura
                    ? Icons.receipt_long_outlined
                    : Icons.sell_outlined),
                title: Text(t.label),
                subtitle: Text(t == FaturaTipo.fatura
                    ? 'Foto ou PDF da fatura de uma compra'
                    : 'Lista de preços do fornecedor (foto ou PDF)'),
              ),
            ),
        ],
      ),
    );
    if (tipo == null || !context.mounted) return;

    final forn = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fornecedor'),
        content: TextField(
          controller: forn,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ex.: Makro'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Escolher ficheiro'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      withData: true,
    );
    final f = picked?.files.single;
    if (f?.bytes == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context)
      ..showSnackBar(const SnackBar(
        content: Text('A analisar a fatura…'),
        duration: Duration(seconds: 8),
      ));
    try {
      final fatura = await ref.read(invoiceActionsProvider).criarEAnalisar(
            tipo: tipo,
            fornecedor: forn.text,
            bytes: f!.bytes!.toList(),
            nome: f.name,
          );
      messenger.hideCurrentSnackBar();
      if (context.mounted) {
        unawaited(context.push('${Routes.invoices}/${fatura.id}'));
      }
    } on Object catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _apagar(BuildContext context, WidgetRef ref, Fatura f) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmDialog(
      context,
      titulo: 'Apagar fatura?',
      mensagem: '${f.fornecedor.isEmpty ? 'Fatura' : f.fornecedor}'
          '${f.numero.isEmpty ? '' : ' nº ${f.numero}'} — '
          'remove o registo e o ficheiro.',
      confirmar: 'Apagar',
      destrutivo: true,
    );
    if (!ok) return;
    try {
      await ref.read(invoiceActionsProvider).apagar(f.id);
      messenger.showSnackBar(const SnackBar(content: Text('Fatura apagada.')));
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _limparInvalidas(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmDialog(
      context,
      titulo: 'Limpar faturas?',
      mensagem: 'Apaga as faturas por analisar ("Nova"), as que ficaram com '
          '"Erro" e as analisadas em que a IA não encontrou nenhuma linha. '
          'Fica registo em "Faturas apagadas".',
      confirmar: 'Limpar',
      destrutivo: true,
    );
    if (!ok) return;
    try {
      final n = await ref.read(invoiceActionsProvider).limparInvalidas();
      messenger.showSnackBar(
        SnackBar(content: Text('$n fatura(s) apagada(s).')),
      );
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(faturasListProvider);
    final fmt = ref.watch(moneyFormatProvider);
    final podeEditar = _podeEditar(ref);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
        title: const Text('Faturas'),
        actions: [
          IconButton(
            tooltip: 'Para a contabilidade',
            icon: const Icon(Icons.folder_shared_outlined),
            onPressed: () => showContabilidadeSheet(context, ref),
          ),
          if (podeEditar)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'limpar') _limparInvalidas(context, ref);
                if (v == 'historico') {
                  final emp = ref.read(currentEmpresaProvider).valueOrNull;
                  if (emp != null) {
                    showHistorySheet(
                      context,
                      tipo: 'faturas_apagadas',
                      id: emp.id,
                      titulo: 'Faturas apagadas',
                    );
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'limpar',
                  child: ListTile(
                    leading: Icon(Icons.delete_sweep_outlined),
                    title: Text('Limpar vazias, com erro e sem linhas'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'historico',
                  child: ListTile(
                    leading: Icon(Icons.history),
                    title: Text('Faturas apagadas'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          const HelpActions(topic: HelpTopic.faturas),
        ],
      ),
      floatingActionButton: podeEditar
          ? FloatingActionButton.extended(
              onPressed: () => _nova(context, ref),
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Nova fatura'),
            )
          : null,
      body: AsyncValueView<List<Fatura>>(
        value: async,
        onRetry: () => ref.invalidate(faturasListProvider),
        data: (faturas) {
          if (faturas.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long_outlined,
              titulo: 'Sem faturas',
              mensagem: 'Usa "Nova fatura" e tira/escolhe a foto. '
                  'A IA lê as linhas e tu confirmas.',
            );
          }
          final grupos = <String, List<Fatura>>{};
          for (final f in faturas) {
            final mes = f.dataFatura.isNotEmpty
                ? f.dataFatura.substring(0, 7)
                : (f.created.isNotEmpty ? f.created.substring(0, 7) : '—');
            grupos.putIfAbsent(mes, () => []).add(f);
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              for (final entry in grupos.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    entry.key,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ),
                for (final f in entry.value)
                  Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                    child: ListTile(
                      title: Text(
                        f.fornecedor.isEmpty ? 'Fornecedor?' : f.fornecedor,
                      ),
                      subtitle: Text([
                        f.tipo.label,
                        if (f.numero.isNotEmpty) 'nº ${f.numero}',
                        if (f.dataFatura.isNotEmpty)
                          formatDateShort(f.dataFatura),
                        if (f.total > 0) fmt(f.total),
                      ].join(' · ')),
                      trailing: _EstadoChip(estado: f.estado),
                      onTap: () =>
                          context.push('${Routes.invoices}/${f.id}'),
                      onLongPress: podeEditar
                          ? () => _apagar(context, ref, f)
                          : null,
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _EstadoChip extends StatelessWidget {
  const _EstadoChip({required this.estado});
  final FaturaEstado estado;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (Color bg, Color fg) = switch (estado) {
      FaturaEstado.nova => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
      FaturaEstado.analisada =>
        (cs.secondaryContainer, cs.onSecondaryContainer),
      FaturaEstado.confirmada => (cs.primaryContainer, cs.onPrimaryContainer),
      FaturaEstado.erro => (cs.errorContainer, cs.onErrorContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(estado.label, style: TextStyle(color: fg, fontSize: 12)),
    );
  }
}
