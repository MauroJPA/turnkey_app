import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/formatting/money_provider.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/help_actions.dart';
import '../application/recipes_providers.dart';
import '../domain/recipe.dart';
import 'recipe_form_sheet.dart';

class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  String _q = '';
  CategoriaReceita? _categoria;
  bool _trash = false;
  bool _busy = false;

  bool get _podeEditar => ref.read(currentPapelProvider).canEditBusiness;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final input = await showRecipeFormSheet(context);
    if (input == null) return;
    await _run(() async {
      final r = await ref.read(recipeActionsProvider).create(input);
      if (mounted) context.go('${Routes.recipes}/${r.id}');
    });
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(recipesListProvider(_trash));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
        title: Text(_trash ? 'Receitas · Lixeira' : 'Receitas'),
        actions: [
          const HelpActions(topic: HelpTopic.receitas),
          IconButton(
            tooltip: _trash ? 'Ver ativas' : 'Lixeira',
            icon: Icon(
              _trash ? Icons.menu_book_outlined : Icons.delete_outline,
            ),
            onPressed: () => setState(() => _trash = !_trash),
          ),
          if (_podeEditar && !_trash)
            IconButton(
              tooltip: 'Nova receita',
              icon: const Icon(Icons.add),
              onPressed: _busy ? null : _add,
            ),
        ],
      ),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Procurar receita',
                isDense: true,
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('Todas'),
                    selected: _categoria == null,
                    onSelected: (_) => setState(() => _categoria = null),
                  ),
                ),
                for (final c in CategoriaReceita.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c.label),
                      selected: _categoria == c,
                      onSelected: (_) => setState(() => _categoria = c),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AsyncValueView<List<Receita>>(
              value: listAsync,
              onRetry: () => ref.invalidate(recipesListProvider(_trash)),
              data: (all) {
                final items = all.where((r) {
                  final mq = _q.isEmpty ||
                      r.nome.toLowerCase().contains(_q.toLowerCase());
                  final mc = _categoria == null || r.categoria == _categoria;
                  return mq && mc;
                }).toList();
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      all.isEmpty
                          ? (_trash
                              ? 'Lixeira vazia'
                              : 'Sem receitas. Usa + para criar.')
                          : 'Nada corresponde ao filtro.',
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _tile(items[i], ref.watch(moneyFormatProvider)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(Receita r, MoneyFmt fmt) {
    if (_trash) {
      return ListTile(
        title: Text(r.nome),
        subtitle: Text(r.categoria.label),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Restaurar',
              icon: const Icon(Icons.restore),
              onPressed: _busy
                  ? null
                  : () => _run(
                        () => ref.read(recipeActionsProvider).restore(r.id),
                      ),
            ),
            IconButton(
              tooltip: 'Apagar definitivamente',
              icon: const Icon(Icons.delete_forever),
              onPressed: _busy
                  ? null
                  : () async {
                      final ok = await confirmDialog(
                        context,
                        titulo: 'Apagar definitivamente',
                        mensagem:
                            'Remove a receita e as suas linhas. Não reversível.',
                        confirmar: 'Apagar',
                        destrutivo: true,
                      );
                      if (ok) {
                        await _run(
                          () => ref
                              .read(recipeActionsProvider)
                              .deleteForever(r.id),
                        );
                      }
                    },
            ),
          ],
        ),
      );
    }

    final subtitle = [
      r.categoria.label,
      if (r.rendimentoEsperado > 0)
        '${r.rendimentoEsperado.toStringAsFixed(0)} g',
      if (r.custoReceita > 0) fmt(r.custoReceita),
    ].join(' · ');

    final tile = ListTile(
      title: Text(r.nome),
      subtitle: Text(subtitle),
      trailing: r.publicarComoIngrediente
          ? const Icon(Icons.link, size: 18)
          : const Icon(Icons.chevron_right),
      onTap: () => context.go('${Routes.recipes}/${r.id}'),
      onLongPress: _podeEditar
          ? () =>
              _run(() => ref.read(recipeActionsProvider).duplicate(r.id))
          : null,
    );

    if (!_podeEditar) return tile;

    return Dismissible(
      key: ValueKey(r.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline),
      ),
      confirmDismiss: (_) => confirmDialog(
        context,
        titulo: 'Mover para a lixeira',
        mensagem: 'Mover "${r.nome}" para a lixeira?',
        confirmar: 'Mover',
      ),
      onDismissed: (_) =>
          _run(() => ref.read(recipeActionsProvider).moveToTrash(r.id)),
      child: tile,
    );
  }
}
