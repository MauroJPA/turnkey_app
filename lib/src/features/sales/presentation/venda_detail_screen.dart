import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/formatting/money_provider.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../application/sales_providers.dart';
import '../domain/venda.dart';
import 'campo_sugestoes.dart';

class VendaDetailScreen extends ConsumerWidget {
  const VendaDetailScreen({super.key, required this.vendaId});
  final String vendaId;

  bool _podeEditar(WidgetRef ref) =>
      ref.read(currentPapelProvider).canEditBusiness;

  Future<void> _remover(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      titulo: 'Apagar venda',
      mensagem: 'Esta venda e as suas linhas serão apagadas. Não é reversível.',
      destrutivo: true,
      confirmar: 'Apagar',
    );
    if (!ok) return;
    await ref.read(salesActionsProvider).remover(vendaId);
    if (context.mounted) context.go(Routes.sales);
  }

  Future<void> _editarCanal(
    BuildContext context,
    WidgetRef ref,
    Venda v,
  ) async {
    final r = await showDialog<({String canal, String metodo})>(
      context: context,
      builder: (_) => _CanalDialog(canal: v.canal, metodo: v.metodoPagamento),
    );
    if (r == null) return;
    final c = r.canal;
    final m = r.metodo;
    await ref
        .read(salesActionsProvider)
        .definirCanal(vendaId, canal: c, metodoPagamento: m);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendaAsync = ref.watch(vendaByIdProvider(vendaId));
    final itensAsync = ref.watch(vendaItensProvider(vendaId));
    final fmt = ref.watch(moneyFormatProvider);
    final podeEditar = _podeEditar(ref);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.sales),
        ),
        title: const Text('Venda'),
        actions: [
          if (podeEditar)
            IconButton(
              tooltip: 'Apagar',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _remover(context, ref),
            ),
        ],
      ),
      body: AsyncValueView<List<VendaItem>>(
        value: itensAsync,
        onRetry: () => ref.invalidate(vendaItensProvider(vendaId)),
        data: (itens) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              vendaAsync.maybeWhen(
                data: (v) => Text(
                  '${v.data.day.toString().padLeft(2, '0')}/'
                  '${v.data.month.toString().padLeft(2, '0')}/'
                  '${v.data.year} · ${v.origem.label}'
                  '${v.numeroDocumento.isNotEmpty ? ' · ${v.numeroDocumento}' : ''}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              vendaAsync.maybeWhen(
                data: (v) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Canal: ${v.canal.isEmpty ? 'não indicado' : v.canal}'
                          '${v.hora.isNotEmpty ? ' · ${v.hora}' : ''}'
                          '${v.metodoPagamento.isNotEmpty ? ' · ${v.metodoPagamento}' : ''}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      if (podeEditar)
                        TextButton.icon(
                          onPressed: () => _editarCanal(context, ref, v),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Canal'),
                        ),
                    ],
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
              if (itens.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Sem linhas.'),
                )
              else
                for (final it in itens)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      it.temFicha
                          ? Icons.check_circle_outline
                          : Icons.help_outline,
                      color: it.temFicha
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      it.descricao.isEmpty ? '(sem descrição)' : it.descricao,
                    ),
                    subtitle: Text(
                      '${it.quantidade.toStringAsFixed(it.quantidade == it.quantidade.roundToDouble() ? 0 : 2)} '
                      '× ${fmt(it.precoUnitario)}',
                    ),
                    trailing: Text(
                      fmt(it.totalLinha),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
              const Divider(height: 24),
              vendaAsync.maybeWhen(
                data: (v) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      fmt(v.total),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Diálogo "Canal e pagamento": gere os seus próprios controladores (se fossem
/// libertados por quem o abre, o menu ainda os usaria durante a animação de
/// saída).
class _CanalDialog extends StatefulWidget {
  const _CanalDialog({required this.canal, required this.metodo});
  final String canal;
  final String metodo;

  @override
  State<_CanalDialog> createState() => _CanalDialogState();
}

class _CanalDialogState extends State<_CanalDialog> {
  late final _canal = TextEditingController(text: widget.canal);
  late final _metodo = TextEditingController(text: widget.metodo);

  @override
  void dispose() {
    _canal.dispose();
    _metodo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Canal e pagamento'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CampoSugestoes(
              controller: _canal,
              label: 'Canal de venda',
              sugestoes: canaisVenda,
            ),
            const SizedBox(height: 12),
            CampoSugestoes(
              controller: _metodo,
              label: 'Método de pagamento',
              sugestoes: metodosPagamento,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (
            canal: _canal.text,
            metodo: _metodo.text,
          )),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
