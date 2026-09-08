import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/formatting/money_provider.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/help_button.dart';
import '../application/shopping_providers.dart';
import '../domain/shopping_item.dart';

class ShoppingScreen extends ConsumerWidget {
  const ShoppingScreen({super.key});

  bool _podeEditar(WidgetRef ref) =>
      ref.read(currentPapelProvider).canEditBusiness;

  Future<void> _reorganizar(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      titulo: 'Reorganizar lista?',
      mensagem:
          'Remove as linhas já compradas (o stock delas já entrou ao dar o '
          'visto) e recalcula o que falta comprar face ao stock atual.',
      confirmar: 'Reorganizar',
    );
    if (!ok) return;
    try {
      final r = await ref.read(shoppingActionsProvider).reorganizar();
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
  }

  Future<void> _limparTudo(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      titulo: 'Limpar toda a lista?',
      mensagem:
          'Apaga todos os itens da lista de compras (comprados e por comprar). '
          'Não altera o inventário. Não é possível desfazer.',
      confirmar: 'Limpar tudo',
      destrutivo: true,
    );
    if (!ok) return;
    try {
      final n = await ref.read(shoppingActionsProvider).limparTudo();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$n item(s) apagado(s).')),
        );
      }
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _addManual(BuildContext context, WidgetRef ref) async {
    final r = await showModalBottomSheet<_ManualItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ManualItemSheet(),
    );
    if (r == null || r.descricao.isEmpty) return;
    await ref.read(shoppingActionsProvider).adicionarManual(
          descricao: r.descricao,
          fornecedor: r.fornecedor,
          quantidade: r.quantidade,
          unidade: r.unidade,
          notas: r.notas,
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
        title: const Text('Lista de compras'),
        actions: [
          const HelpButton(topic: HelpTopic.compras),
          if (podeEditar)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'reorganizar') _reorganizar(context, ref);
                if (v == 'limpar') _limparTudo(context, ref);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'reorganizar',
                  child: ListTile(
                    leading: Icon(Icons.autorenew),
                    title: Text('Reorganizar lista'),
                    subtitle: Text('Remove comprados e recalcula'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'limpar',
                  child: ListTile(
                    leading: Icon(Icons.delete_sweep_outlined),
                    title: Text('Limpar lista'),
                    subtitle: Text('Apaga tudo'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
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
            return const EmptyState(
              icon: Icons.shopping_cart_outlined,
              titulo: 'Lista de compras vazia',
              mensagem: 'Abra uma produção na Agenda e toque em "Adicionar à lista de compras".',
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

    final descricao = (sacos != null && sacos > 0)
        ? '$sacos  ${item.descricao}'
        : (!item.emGramas
            ? '${item.quantidadeTexto()}  ${item.descricao}'
            : item.descricao);

    final String detalhe;
    if (!item.emGramas) {
      detalhe = 'Comprar ${item.quantidadeTexto()}';
    } else if (item.necessariaG <= 0) {
      detalhe = 'Comprar ${ShoppingItem.gramasLabel(item.comprarG)}';
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
      isThreeLine: item.notas.isNotEmpty,
      title: Text(descricao, style: risca),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(detalhe),
          if (item.notas.isNotEmpty)
            Text(
              item.notas,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
            ),
        ],
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

typedef _ManualItem = ({
  String descricao,
  String fornecedor,
  double quantidade,
  String unidade,
  String notas,
});

/// Folha "Novo item" da lista de compras — para qualquer coisa da empresa
/// (não só ingredientes): sacos de lixo, sabão, uma tesoura…
class _ManualItemSheet extends StatefulWidget {
  const _ManualItemSheet();

  @override
  State<_ManualItemSheet> createState() => _ManualItemSheetState();
}

class _ManualItemSheetState extends State<_ManualItemSheet> {
  final _desc = TextEditingController();
  final _forn = TextEditingController();
  final _qtd = TextEditingController(text: '1');
  final _notas = TextEditingController();
  String _unidade = 'un';

  static const _unidades = ['un', 'g', 'kg', 'caixa', 'pacote', 'litro'];

  @override
  void dispose() {
    _desc.dispose();
    _forn.dispose();
    _qtd.dispose();
    _notas.dispose();
    super.dispose();
  }

  void _guardar() {
    final d = _desc.text.trim();
    if (d.isEmpty) return;
    Navigator.pop(context, (
      descricao: d,
      fornecedor: _forn.text.trim(),
      quantidade:
          double.tryParse(_qtd.text.replaceAll(',', '.').trim()) ?? 0,
      unidade: _unidade,
      notas: _notas.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Novo item', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _desc,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'O que comprar *'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _forn,
            decoration: const InputDecoration(labelText: 'Fornecedor / loja'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qtd,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Quantidade'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _unidade,
                  decoration: const InputDecoration(labelText: 'Unidade'),
                  items: [
                    for (final u in _unidades)
                      DropdownMenuItem(value: u, child: Text(u)),
                  ],
                  onChanged: (v) => setState(() => _unidade = v ?? 'un'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notas,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nota (opcional)',
              hintText: 'Ex.: tesoura de bico fino — a faca demora muito',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _guardar,
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }
}
