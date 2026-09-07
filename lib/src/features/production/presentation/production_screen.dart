import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/formatting/money_provider.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../recipes/application/recipes_providers.dart';
import '../../recipes/domain/recipe.dart';
import '../application/production_providers.dart';
import '../domain/production.dart';

class ProductionScreen extends ConsumerStatefulWidget {
  const ProductionScreen({super.key});

  @override
  ConsumerState<ProductionScreen> createState() => _ProductionScreenState();
}

class _ProductionScreenState extends ConsumerState<ProductionScreen> {
  Receita? _receita;
  final _kg = TextEditingController();

  @override
  void dispose() {
    _kg.dispose();
    super.dispose();
  }

  double get _alvoG {
    final kg = double.tryParse(_kg.text.replaceAll(',', '.').trim()) ?? 0;
    return kg * 1000;
  }

  Future<void> _escolher() async {
    final r = await showModalBottomSheet<Receita>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _RecipePicker(),
    );
    if (r != null) setState(() => _receita = r);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = ref.watch(moneyFormatProvider);
    final pronto = _receita != null && _alvoG > 0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
        title: const Text('Produzir'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text(_receita?.nome ?? 'Escolher produto'),
              subtitle: _receita == null
                  ? const Text('Receita de fabrico próprio')
                  : Text(
                      '${_receita!.categoria.label} · rendimento base '
                      '${_receita!.rendimentoEsperado.toStringAsFixed(0)} g',
                    ),
              trailing: const Icon(Icons.expand_more),
              onTap: _escolher,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _kg,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Quantidade a produzir',
              suffixText: 'kg',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          if (!pronto)
            const Padding(
              padding: EdgeInsets.only(top: 32),
              child: Center(
                child: Text('Escolhe um produto e indica os kg.'),
              ),
            )
          else
            AsyncValueView<ProductionNode>(
              value: ref.watch(
                productionProvider(
                  (recipeId: _receita!.id, alvoG: _alvoG),
                ),
              ),
              onRetry: () => ref.invalidate(
                productionProvider(
                  (recipeId: _receita!.id, alvoG: _alvoG),
                ),
              ),
              data: (node) => _NodeView(node: node, fmt: fmt, nivel: 0),
            ),
        ],
      ),
    );
  }
}

class _NodeView extends StatelessWidget {
  const _NodeView({
    required this.node,
    required this.fmt,
    required this.nivel,
  });

  final ProductionNode node;
  final MoneyFmt fmt;
  final int nivel;

  String _g(double g) => g >= 1000
      ? '${(g / 1000).toStringAsFixed(3)} kg'
      : '${g.toStringAsFixed(g < 10 ? 1 : 0)} g';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: EdgeInsets.only(left: nivel * 12.0, top: nivel == 0 ? 0 : 8),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  node.nome,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: scheme.primary),
                ),
                const SizedBox(height: 2),
                if (node.ciclo)
                  Text(
                    'Sub-receita em ciclo — não expandida.',
                    style: TextStyle(color: scheme.error),
                  )
                else if (node.semRendimento)
                  Text(
                    'Sem rendimento definido — não é possível escalar.',
                    style: TextStyle(color: scheme.error),
                  )
                else
                  Text(
                    'Produzir ${_g(node.alvoG)}  ·  '
                    '×${node.fator.toStringAsFixed(3)}  ·  '
                    'base ${_g(node.rendimentoBase)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          if (!node.ciclo && !node.semRendimento) ...[
            for (final l in node.linhas)
              ListTile(
                dense: true,
                title: Text(
                  l.nome,
                  style: l.pendente
                      ? TextStyle(color: scheme.error)
                      : null,
                ),
                trailing: Text(
                  _g(l.quantidadeG),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: l.pendente
                    ? const Text('vínculo pendente')
                    : Text(fmt(l.custo)),
              ),
            for (final sub in node.subReceitas)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: _NodeView(node: sub, fmt: fmt, nivel: nivel + 1),
              ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total ${node.nome}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    fmt(node.custoTotal),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Escolhe uma receita (produto de fabrico próprio).
class _RecipePicker extends ConsumerStatefulWidget {
  const _RecipePicker();

  @override
  ConsumerState<_RecipePicker> createState() => _RecipePickerState();
}

class _RecipePickerState extends ConsumerState<_RecipePicker> {
  String _q = '';
  bool _soFabricoProprio = true;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(recipesListProvider(false));
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Procurar receita',
                isDense: true,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Só produtos de fabrico próprio'),
              value: _soFabricoProprio,
              onChanged: (v) => setState(() => _soFabricoProprio = v),
            ),
            Expanded(
              child: AsyncValueView<List<Receita>>(
                value: async,
                data: (all) {
                  final items = all.where((r) {
                    final mq = _q.isEmpty ||
                        r.nome.toLowerCase().contains(_q.toLowerCase());
                    final mf =
                        !_soFabricoProprio || r.publicarComoIngrediente;
                    return mq && mf;
                  }).toList();
                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) => ListTile(
                      title: Text(items[i].nome),
                      subtitle: Text(
                        '${items[i].categoria.label} · '
                        '${items[i].rendimentoEsperado.toStringAsFixed(0)} g',
                      ),
                      onTap: () => Navigator.pop(context, items[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
