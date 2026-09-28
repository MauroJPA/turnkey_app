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
import '../../../core/widgets/sort_menu_button.dart';
import '../../../core/widgets/swipe_to_delete.dart';
import '../application/recipes_providers.dart';
import '../domain/recipe.dart';
import 'receitas_import_sheet.dart';
import 'recipe_form_sheet.dart';

class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  String _q = '';
  String? _categoria;
  bool _trash = false;
  bool _busy = false;

  static final List<SortOption<Receita>> _sortOptions = [
    SortOption<Receita>(
      'Nome',
      (a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()),
    ),
    SortOption<Receita>(
      'Categoria',
      (a, b) => a.categoria.toLowerCase().compareTo(b.categoria.toLowerCase()),
    ),
    SortOption<Receita>(
      'Custo',
      (a, b) => a.custoReceita.compareTo(b.custoReceita),
    ),
  ];
  int _sortIndex = 0;
  bool _sortAsc = true;

  bool get _podeEditar => ref.read(currentPapelProvider).canEditBusiness;

  Future<bool> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      return true;
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final res = await showRecipeFormSheet(context);
    if (res == null) return;
    await _run(() async {
      final actions = ref.read(recipeActionsProvider);
      final r = await actions.create(res.input);
      if (res.imagens.isNotEmpty) {
        await actions.adicionarImagens(r.id, res.imagens);
      }
      if (mounted) context.go('${Routes.recipes}/${r.id}');
    });
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(recipesListProvider(_trash));
    // categorias que aparecem nas receitas carregadas — não uma lista fixa,
    // já que agora são geríveis pela empresa (podem ser criadas/renomeadas).
    final categoriasEmUso =
        (listAsync.valueOrNull ?? const <Receita>[])
            .map((r) => r.categoria)
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
        title: Text(_trash ? 'Receitas · Lixeira' : 'Receitas'),
        actions: [
          const HelpActions(topic: HelpTopic.receitas),
          if (!_trash)
            SortMenuButton<Receita>(
              options: _sortOptions,
              selectedIndex: _sortIndex,
              ascending: _sortAsc,
              onChanged: (i, asc) => setState(() {
                _sortIndex = i;
                _sortAsc = asc;
              }),
            ),
          IconButton(
            tooltip: _trash ? 'Ver ativas' : 'Lixeira',
            icon: Icon(
              _trash ? Icons.menu_book_outlined : Icons.delete_outline,
            ),
            onPressed: () => setState(() => _trash = !_trash),
          ),
          if (_podeEditar && !_trash)
            IconButton(
              tooltip: 'Importar receitas (CSV / colar)',
              icon: const Icon(Icons.upload_file_outlined),
              onPressed: _busy
                  ? null
                  : () => showImportarReceitasSheet(context),
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
                for (final c in categoriasEmUso)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c),
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
                final items = ordenarPor(
                  all.where((r) {
                    final mq =
                        _q.isEmpty ||
                        r.nome.toLowerCase().contains(_q.toLowerCase());
                    final mc = _categoria == null || r.categoria == _categoria;
                    return mq && mc;
                  }).toList(),
                  _sortOptions[_sortIndex],
                  _sortAsc,
                );
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
                  itemBuilder: (_, i) =>
                      _tile(items[i], ref.watch(moneyFormatProvider)),
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
        subtitle: Text(r.categoria),
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
      r.categoria,
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
          ? () => _run(() => ref.read(recipeActionsProvider).duplicate(r.id))
          : null,
    );

    if (!_podeEditar) return tile;

    return SwipeToDelete(
      key: ValueKey(r.id),
      confirmar: () => confirmDialog(
        context,
        titulo: 'Mover para a lixeira',
        mensagem: 'Mover "${r.nome}" para a lixeira?',
        confirmar: 'Mover',
      ),
      apagar: () =>
          _run(() => ref.read(recipeActionsProvider).moveToTrash(r.id)),
      child: tile,
    );
  }
}
