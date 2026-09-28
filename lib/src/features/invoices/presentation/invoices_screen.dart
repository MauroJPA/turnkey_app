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
import '../application/analise_faturas_controller.dart';
import '../application/invoice_providers.dart';
import '../domain/fatura.dart';
import '../domain/invoice_erros.dart';
import 'analise_faturas_widgets.dart';
import 'contabilidade_sheet.dart';
import 'invoice_owner_widgets.dart';

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  bool _selecionando = false;
  final Set<String> _selecionadas = {};

  bool _podeEditar(WidgetRef ref) =>
      ref.read(currentPapelProvider).canEditBusiness;

  void _alternarSelecao(String id) {
    setState(() {
      if (_selecionadas.contains(id)) {
        _selecionadas.remove(id);
      } else {
        _selecionadas.add(id);
      }
    });
  }

  void _sairDaSelecao() {
    setState(() {
      _selecionando = false;
      _selecionadas.clear();
    });
  }

  Future<void> _marcarIgnoradas(BuildContext context, WidgetRef ref) async {
    if (_selecionadas.isEmpty) return;
    final n = _selecionadas.length;
    final ok = await confirmDialog(
      context,
      titulo: 'Marcar $n fatura(s) como ignorada(s)?',
      mensagem:
          'Não apaga nada — os ficheiros ficam guardados. Só deixam de pedir '
          'revisão (não atualizam preço nem stock). Reabrir uma delas e '
          'decidir uma linha tira-a sozinha deste estado.',
      confirmar: 'Ignorar',
    );
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final ids = _selecionadas.toList();
    _sairDaSelecao();
    try {
      final feitas = await ref.read(invoiceActionsProvider).ignorarLote(ids);
      messenger.showSnackBar(
        SnackBar(
          content: Text('$feitas fatura(s) marcada(s) como ignorada(s).'),
        ),
      );
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
    }
  }

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
                leading: Icon(
                  t == FaturaTipo.fatura
                      ? Icons.receipt_long_outlined
                      : Icons.sell_outlined,
                ),
                title: Text(t.label),
                subtitle: Text(
                  t == FaturaTipo.fatura
                      ? 'Foto ou PDF da fatura de uma compra'
                      : 'Lista de preços do fornecedor (foto ou PDF)',
                ),
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
        title: const Text('Fornecedor (opcional)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: forn,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Ex.: Makro'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Podes deixar em branco: a IA lê o fornecedor da fatura. Se o '
              'PDF tiver várias faturas (de fornecedores diferentes), cada uma '
              'fica com o seu ficheiro.',
              style: TextStyle(fontSize: 12),
            ),
          ],
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

    // O envio e a análise correm em segundo plano (mesmo que mudes de ecrã); o
    // progresso aparece aqui e numa faixa por cima da barra de navegação.
    ref
        .read(analiseFaturasProvider.notifier)
        .iniciar(
          tipo: tipo,
          fornecedor: forn.text.trim(),
          bytes: f!.bytes!, // sem copiar (PDFs de dezenas de MB)
          nome: f.name,
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'A enviar e analisar o ficheiro. Acompanha o progresso aqui.',
        ),
      ),
    );
  }

  /// Toque longo numa fatura (só o proprietário): corrigir os dados ou apagar.
  Future<void> _opcoesFatura(
    BuildContext context,
    WidgetRef ref,
    Fatura f,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final escolha = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Corrigir fornecedor, data, número…'),
              onTap: () => Navigator.pop(ctx, 'editar'),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Ver o histórico desta fatura'),
              onTap: () => Navigator.pop(ctx, 'historico'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Apagar'),
              onTap: () => Navigator.pop(ctx, 'apagar'),
            ),
          ],
        ),
      ),
    );
    if (escolha == null || !context.mounted) return;
    try {
      switch (escolha) {
        case 'editar':
          if (await mostrarEditarFatura(context, ref, f)) {
            messenger.showSnackBar(
              const SnackBar(content: Text('Guardado. Fica no histórico.')),
            );
          }
        case 'historico':
          showHistorySheet(
            context,
            tipo: 'fatura',
            id: f.id,
            titulo: f.fornecedor.isEmpty ? 'Fatura' : f.fornecedor,
          );
        case 'apagar':
          if (await apagarFaturaComConfirmacao(context, ref, f)) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Fatura apagada (podes restaurá-la).'),
              ),
            );
          }
      }
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
    }
  }

  Future<void> _limparInvalidas(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmDialog(
      context,
      titulo: 'Limpar faturas?',
      mensagem:
          'Apaga (podes restaurar) as faturas por analisar ("Nova"), as que ficaram com '
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
      messenger.showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(faturasListProvider);
    final fmt = ref.watch(moneyFormatProvider);
    final podeEditar = _podeEditar(ref);
    final podeGerir = ehProprietarioOuAdmin(ref);

    return Scaffold(
      appBar: _selecionando
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cancelar seleção',
                onPressed: _sairDaSelecao,
              ),
              title: Text('${_selecionadas.length} selecionada(s)'),
              actions: [
                TextButton(
                  onPressed: _selecionadas.isEmpty
                      ? null
                      : () => _marcarIgnoradas(context, ref),
                  child: const Text('Marcar como ignorada'),
                ),
              ],
            )
          : AppBar(
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
                  IconButton(
                    tooltip: 'Selecionar várias para marcar como ignoradas',
                    icon: const Icon(Icons.checklist_outlined),
                    onPressed: () => setState(() => _selecionando = true),
                  ),
                if (podeGerir)
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'limpar') _limparInvalidas(context, ref);
                      if (v == 'historico') mostrarFaturasApagadas(context);
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
      floatingActionButton: podeEditar && !_selecionando
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
            if (ref.watch(analiseFaturasProvider).isNotEmpty) {
              return const SingleChildScrollView(child: AnaliseFaturasPainel());
            }
            return const EmptyState(
              icon: Icons.receipt_long_outlined,
              titulo: 'Sem faturas',
              mensagem:
                  'Usa "Nova fatura" e tira/escolhe a foto. '
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
          final trabalhos = ref.watch(analiseFaturasProvider);
          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              const AnaliseFaturasPainel(),
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
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 3,
                    ),
                    child: ListTile(
                      leading: _selecionando
                          ? Checkbox(
                              value: _selecionadas.contains(f.id),
                              onChanged: (_) => _alternarSelecao(f.id),
                            )
                          : null,
                      title: Text(
                        f.fornecedor.isEmpty ? 'Fornecedor?' : f.fornecedor,
                      ),
                      subtitle: Text(
                        [
                          f.tipo.label,
                          if (f.numero.isNotEmpty) 'nº ${f.numero}',
                          if (f.dataFatura.isNotEmpty)
                            formatDateShort(f.dataFatura),
                          if (f.total > 0) fmt(f.total),
                        ].join(' · '),
                      ),
                      trailing: f.analiseAMeio && podeEditar
                          ? (trabalhos[f.id]?.ativo ?? false)
                                ? const _EstadoChip.texto('A analisar…')
                                : TextButton(
                                    onPressed: () => ref
                                        .read(analiseFaturasProvider.notifier)
                                        .retomar(
                                          f.id,
                                          titulo: f.ficheiro.isNotEmpty
                                              ? f.ficheiro
                                              : 'Fatura',
                                        ),
                                    child: Text(
                                      f.temLote && f.loteFeitas > 0
                                          ? 'Continuar (${f.loteFeitas}/${f.lotePaginas})'
                                          : 'Analisar',
                                    ),
                                  )
                          : (f.estado == FaturaEstado.erro &&
                                    f.duplicadaDe.isNotEmpty
                                ? const _EstadoChip.texto('Duplicada')
                                : (f.temPendentes
                                      ? _EstadoChip.texto(
                                          '${f.pendentesLinhas} por rever',
                                        )
                                      : _EstadoChip(estado: f.estado))),
                      onTap: _selecionando
                          ? () => _alternarSelecao(f.id)
                          : () => context.push('${Routes.invoices}/${f.id}'),
                      onLongPress: _selecionando || !podeGerir
                          ? null
                          : () => _opcoesFatura(context, ref, f),
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
  const _EstadoChip({required this.estado}) : textoLivre = null;

  /// Chip com um texto próprio (ex.: "A analisar…").
  const _EstadoChip.texto(this.textoLivre) : estado = FaturaEstado.nova;

  final FaturaEstado estado;
  final String? textoLivre;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (Color bg, Color fg) = switch (estado) {
      FaturaEstado.nova => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
      FaturaEstado.analisada => (
        cs.secondaryContainer,
        cs.onSecondaryContainer,
      ),
      FaturaEstado.confirmada => (cs.primaryContainer, cs.onPrimaryContainer),
      FaturaEstado.erro => (cs.errorContainer, cs.onErrorContainer),
      FaturaEstado.ignorada => (
        cs.surfaceContainerHighest,
        cs.onSurfaceVariant,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        textoLivre ?? estado.label,
        style: TextStyle(color: fg, fontSize: 12),
      ),
    );
  }
}
