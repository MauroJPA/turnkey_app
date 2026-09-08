import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../application/shopping_providers.dart';
import '../domain/shopping_item.dart';

class ShoppingScreen extends ConsumerWidget {
  const ShoppingScreen({super.key});

  bool _podeEditar(WidgetRef ref) =>
      ref.read(currentPapelProvider).canEditBusiness;

  Future<void> _addManual(BuildContext context, WidgetRef ref) async {
    final desc = TextEditingController();
    final forn = TextEditingController();
    final qtd = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Novo item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: desc,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Descrição'),
            ),
            TextField(
              controller: forn,
              decoration: const InputDecoration(labelText: 'Fornecedor'),
            ),
            TextField(
              controller: qtd,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Quantidade a comprar',
                suffixText: 'g',
              ),
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
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
    if (ok != true || desc.text.trim().isEmpty) return;
    await ref.read(shoppingActionsProvider).adicionarManual(
          descricao: desc.text.trim(),
          fornecedor: forn.text.trim(),
          comprarG:
              double.tryParse(qtd.text.replaceAll(',', '.').trim()) ?? 0,
        );
  }

  Future<void> _editarComprar(
    BuildContext context,
    WidgetRef ref,
    ShoppingItem item,
  ) async {
    final ctrl = TextEditingController(
      text: item.comprarG.toStringAsFixed(0),
    );
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.descricao),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'A comprar',
            suffixText: 'g',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              double.tryParse(ctrl.text.replaceAll(',', '.').trim()) ?? 0,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (v == null) return;
    await ref.read(shoppingActionsProvider).editarComprar(item.id, v);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(shoppingListProvider);
    final podeEditar = _podeEditar(ref);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
        title: const Text('Lista de compras'),
        actions: [
          if (podeEditar)
            IconButton(
              tooltip: 'Remover comprados',
              icon: const Icon(Icons.cleaning_services_outlined),
              onPressed: () async {
                final ok = await confirmDialog(
                  context,
                  titulo: 'Remover itens comprados?',
                  mensagem: 'Apaga da lista as linhas já marcadas. '
                      'O stock não é alterado.',
                  confirmar: 'Remover',
                  destrutivo: true,
                );
                if (!ok) return;
                final n =
                    await ref.read(shoppingActionsProvider).limparComprados();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$n item(s) removido(s).')),
                  );
                }
              },
            ),
        ],
      ),
      floatingActionButton: podeEditar
          ? FloatingActionButton.extended(
              onPressed: () => _addManual(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Item'),
            )
          : null,
      body: AsyncValueView<List<ShoppingItem>>(
        value: async,
        onRetry: () => ref.invalidate(shoppingListProvider),
        data: (itens) {
          if (itens.isEmpty) {
            return const Center(
              child: Text('Lista vazia. Gera a partir de uma produção.'),
            );
          }
          final grupos = <String, List<ShoppingItem>>{};
          for (final i in itens) {
            grupos.putIfAbsent(i.grupo, () => []).add(i);
          }
          final totalComprar = itens
              .where((i) => !i.comprado)
              .fold<double>(0, (s, i) => s + i.comprarG);

          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  'Em falta: ${ShoppingItem.gramasLabel(totalComprar)} '
                  '· ${itens.where((i) => !i.comprado).length} item(s)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
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
                for (final item in entry.value)
                  _Linha(
                    item: item,
                    podeEditar: podeEditar,
                    onToggle: (v) => ref
                        .read(shoppingActionsProvider)
                        .definirComprado(item, v),
                    onEditar: () => _editarComprar(context, ref, item),
                    onRemover: () =>
                        ref.read(shoppingActionsProvider).remover(item.id),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha({
    required this.item,
    required this.podeEditar,
    required this.onToggle,
    required this.onEditar,
    required this.onRemover,
  });

  final ShoppingItem item;
  final bool podeEditar;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEditar;
  final VoidCallback onRemover;

  @override
  Widget build(BuildContext context) {
    final sacos = item.sacos;
    return CheckboxListTile(
      controlAffinity: ListTileControlAffinity.leading,
      value: item.comprado,
      onChanged:
          podeEditar ? (v) => onToggle(v ?? false) : null,
      title: Text(
        item.descricao,
        style: item.comprado
            ? const TextStyle(
                decoration: TextDecoration.lineThrough,
              )
            : null,
      ),
      subtitle: Text(
        item.necessariaG > 0
            ? [
                if (sacos != null && sacos > 0)
                  '$sacos ${sacos == 1 ? 'saco' : 'sacos'} de '
                      '${ShoppingItem.gramasLabel(item.embalagemG)}',
                'precisa ${ShoppingItem.gramasLabel(item.necessariaG)}',
              ].join(' · ')
            : 'Item manual',
      ),
      secondary: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: podeEditar ? onEditar : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  ShoppingItem.gramasLabel(item.comprarG),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (podeEditar)
                  Text(
                    'editar',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          if (podeEditar)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Remover',
              onPressed: onRemover,
            ),
        ],
      ),
    );
  }
}
