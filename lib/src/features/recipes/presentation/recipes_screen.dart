import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/errors/mensagem_amigavel.dart';
import '../../../core/formatting/money_provider.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/help_actions.dart';
import '../../../core/widgets/pendencia_aviso.dart';
import '../../../core/widgets/sort_menu_button.dart';
import '../../../core/widgets/swipe_to_delete.dart';
import '../../recipe_categories/application/categoria_receita_providers.dart';
import '../../recipe_categories/presentation/pedir_nome_categoria.dart';
import '../application/recipes_providers.dart';
import '../domain/recipe.dart';
import 'auto_link_pendentes_sheet.dart';
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
        ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
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

  Future<void> _renomearCategoria(String atual) async {
    final n = await pedirNomeCategoria(
      context,
      inicial: atual,
      titulo: 'Mudar o nome da categoria',
      dica: 'Muda em todas as receitas que usam "$atual".',
    );
    if (n == null || n == atual || !mounted) return;
    try {
      await renomearCategoriaReceita(ref, de: atual, para: n);
      if (mounted && _categoria == atual) setState(() => _categoria = n);
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
      }
    }
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

    final contagem = <String, int>{};
    for (final r in listAsync.valueOrNull ?? const <Receita>[]) {
      contagem[r.categoria] = (contagem[r.categoria] ?? 0) + 1;
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
        title: Text(_trash ? 'Receitas · Lixeira' : 'Receitas'),
        actions: [
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
          // "+": nova receita à mão, ou importar várias de uma vez
          if (_podeEditar && !_trash)
            PopupMenuButton<void>(
              tooltip: 'Nova receita',
              icon: const Icon(Icons.add),
              enabled: !_busy,
              itemBuilder: (_) => [
                PopupMenuItem(
                  onTap: _add,
                  child: const _ItemMenu(Icons.edit_outlined, 'Nova receita'),
                ),
                PopupMenuItem(
                  onTap: () => showImportarReceitasSheet(context),
                  child: const _ItemMenu(
                    Icons.upload_file_outlined,
                    'Importar receitas (CSV / colar)',
                  ),
                ),
              ],
            ),
          const HelpActions(topic: HelpTopic.receitas),
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
                    child: GestureDetector(
                      // manter premido: mudar o nome da categoria
                      onLongPress: _trash || !_podeEditar
                          ? null
                          : () => _renomearCategoria(c),
                      child: ChoiceChip(
                        label: Text('$c (${contagem[c] ?? 0})'),
                        selected: _categoria == c,
                        onSelected: (_) => setState(() => _categoria = c),
                      ),
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
                final pendencias =
                    ref.watch(receitasComPendenciasProvider).valueOrNull ??
                    const <String>{};
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _tile(
                    items[i],
                    ref.watch(moneyFormatProvider),
                    pendencias.contains(items[i].id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(Receita r, MoneyFmt fmt, bool temPendencias) {
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

    final partes = [
      r.categoria,
      if (r.rendimentoEsperado > 0)
        '${r.rendimentoEsperado.toStringAsFixed(0)} g',
    ].join(' · ');
    final cs = Theme.of(context).colorScheme;

    final tile = ListTile(
      title: Text(r.nome),
      subtitle: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(r.custoReceita > 0 ? '$partes · ' : partes),
          if (r.custoReceita > 0)
            Text(
              fmt(r.custoReceita),
              style: temPendencias
                  ? TextStyle(color: cs.error, fontWeight: FontWeight.bold)
                  : null,
            ),
          if (temPendencias) ...[
            const SizedBox(width: 2),
            const PendenciaAviso(
              mensagem:
                  'Este preço não é definitivo: há pelo menos um item da '
                  'receita ainda por ligar a um ingrediente ou sub-receita '
                  '— abre a receita e liga-o para o custo ficar certo.',
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (temPendencias && _podeEditar)
            IconButton(
              tooltip: 'Ligar automaticamente pelo nome',
              icon: const Icon(Icons.auto_fix_high),
              onPressed: _busy
                  ? null
                  : () => ligarPendentesAutomaticamente(context, ref, r.id),
            ),
          r.publicarComoIngrediente
              ? const Icon(Icons.link, size: 18)
              : const Icon(Icons.chevron_right),
        ],
      ),
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

/// Linha de um menu: ícone e texto alinhados.
class _ItemMenu extends StatelessWidget {
  const _ItemMenu(this.icon, this.texto);
  final IconData icon;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(texto)),
      ],
    );
  }
}
