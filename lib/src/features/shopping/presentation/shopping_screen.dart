import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/formatting/money_provider.dart';
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
    final fmt = ref.watch(moneyFormatProvider);

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
              tooltip: 'Reorganizar lista',
              icon: const Icon(Icons.autorenew),
              onPressed: () async {
                final ok = await confirmDialog(
                  context,
                  titulo: 'Reorganizar lista?',
                  mensagem:
                      'Remove as linhas já compradas (o stock delas já entrou '
                      'ao dar o visto) e recalcula o que falta comprar face ao '
                      'stock atual.',
                  confirmar: 'Reorganizar',
                );
                if (!ok) return;
                try {
                  final r =
                      await ref.read(shoppingActionsProvider).reorganizar();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${r.removidas} removida(s) · '
                          '${r.recalculadas} linha(s) recalculada(s).',
                        ),
                      ),
                    );
                  }
                } on Object catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('$e')));
                  }
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
          final totalEsperado =
              itens.fold<double>(0, (s, i) => s + i.custoEstimado);
          final totalComprado = itens
              .where((i) => i.comprado)
              .fold<double>(0, (s, i) => s + i.custoEstimado);
          final falta = itens.where((i) => !i.comprado).length;

          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              Card(
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _linhaTotal(context, 'Total esperado', fmt(totalEsperado),
                          forte: true),
                      const SizedBox(height: 4),
                      _linhaTotal(context, 'Já comprado (visto)',
                          fmt(totalComprado)),
                      const SizedBox(height: 4),
                      _linhaTotal(
                        context,
                        'Ainda em falta',
                        '${fmt(totalEsperado - totalComprado)} · '
                            '$falta ${falta == 1 ? 'item' : 'itens'}',
                      ),
                    ],
                  ),
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
                    fmt: fmt,
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

Widget _linhaTotal(
  BuildContext context,
  String rotulo,
  String valor, {
  bool forte = false,
}) {
  final style = forte
      ? const TextStyle(fontWeight: FontWeight.bold)
      : Theme.of(context).textTheme.bodyMedium;
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(rotulo, style: style),
      Text(valor, style: style),
    ],
  );
}

class _Linha extends StatelessWidget {
  const _Linha({
    required this.item,
    required this.podeEditar,
    required this.fmt,
    required this.onToggle,
    required this.onEditar,
    required this.onRemover,
  });

  final ShoppingItem item;
  final bool podeEditar;
  final MoneyFmt fmt;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEditar;
  final VoidCallback onRemover;

  @override
  Widget build(BuildContext context) {
    final sacos = item.sacos;
    final risca = item.comprado
        ? const TextStyle(decoration: TextDecoration.lineThrough)
        : null;

    final descricao = sacos != null && sacos > 0
        ? '$sacos  ${item.descricao}'
        : item.descricao;

    final String detalhe;
    if (item.necessariaG <= 0) {
      detalhe = 'Item manual';
    } else if (item.embalagemG > 0) {
      detalhe = 'Embalagem de ${ShoppingItem.gramasLabel(item.embalagemG)} — '
          'Precisamos de ${ShoppingItem.gramasLabel(item.necessariaG)}';
    } else {
      detalhe = 'Precisamos de ${ShoppingItem.gramasLabel(item.necessariaG)}'
          ' · comprar ${ShoppingItem.gramasLabel(item.comprarG)}';
    }

    return CheckboxListTile(
      controlAffinity: ListTileControlAffinity.leading,
      value: item.comprado,
      onChanged: podeEditar ? (v) => onToggle(v ?? false) : null,
      isThreeLine: false,
      title: Text(descricao, style: risca),
      subtitle: Text(detalhe),
      secondary: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: podeEditar ? onEditar : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (item.custoEstimado > 0)
                  Text(
                    fmt(item.custoEstimado),
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
