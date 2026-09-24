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
import '../../../core/widgets/history_sheet.dart';
import '../../../core/widgets/swipe_to_delete.dart';
import '../../production/presentation/agenda_line_sheet.dart';
import '../application/recipes_providers.dart';
import '../domain/recipe_item.dart';
import 'item_picker_sheet.dart';
import 'nutricao_receita_sheet.dart';
import 'procedimento_sheet.dart';
import 'recipe_form_sheet.dart';

class RecipeDetailScreen extends ConsumerStatefulWidget {
  const RecipeDetailScreen({super.key, required this.recipeId});
  final String recipeId;

  @override
  ConsumerState<RecipeDetailScreen> createState() =>
      _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  bool _busy = false;

  bool get _podeEditar => ref.read(currentPapelProvider).canEditBusiness;

  Future<bool> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      return true;
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addItem() async {
    final picked = await showItemPickerSheet(
      context,
      excludeRecipeId: widget.recipeId,
    );
    if (picked == null) return;
    await _run(() async {
      final actions = ref.read(recipeActionsProvider);
      if (picked.kind == PickedKind.ingrediente) {
        await actions.addIngrediente(
            widget.recipeId, picked.id, picked.quantidadeG);
      } else {
        await actions.addSubReceita(
            widget.recipeId, picked.id, picked.quantidadeG);
      }
    });
  }

  Future<void> _editQty(ItemReceita item) async {
    final ctrl = TextEditingController(
      text: item.quantidadeG.toStringAsFixed(0),
    );
    final novo = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Quantidade — ${item.nome}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Gramas'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              double.tryParse(ctrl.text.replaceAll(',', '.')),
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (novo == null || novo <= 0) return;
    await _run(
      () => ref
          .read(recipeActionsProvider)
          .setQuantidade(widget.recipeId, item.id, novo),
    );
  }

  Future<void> _vincular(ItemReceita item) async {
    final picked = await showItemPickerSheet(
      context,
      excludeRecipeId: widget.recipeId,
      apenasVincular: true,
    );
    if (picked == null) return;
    await _run(
      () => ref.read(recipeActionsProvider).vincular(
            widget.recipeId,
            item.id,
            ingredienteId: picked.kind == PickedKind.ingrediente
                ? picked.id
                : null,
            subReceitaId: picked.kind == PickedKind.subReceita
                ? picked.id
                : null,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(recipeDetailProvider(widget.recipeId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.recipes),
        ),
        title: Text(
          detailAsync.maybeWhen(
            data: (d) => d.receita.nome,
            orElse: () => 'Receita',
          ),
        ),
        actions: [
          const HelpActions(topic: HelpTopic.receitaDetalhe),
          detailAsync.maybeWhen(
            data: (d) => IconButton(
              tooltip: 'Agendar produção',
              icon: const Icon(Icons.event_note_outlined),
              onPressed: () =>
                  showAgendaLineSheet(context, receita: d.receita),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          detailAsync.maybeWhen(
            data: (d) => IconButton(
              tooltip: 'Procedimento e imagens',
              icon: const Icon(Icons.menu_book_outlined),
              onPressed: () => showProcedimentoSheet(context, d.receita),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          detailAsync.maybeWhen(
            data: (d) => IconButton(
              tooltip: 'Informação nutricional',
              icon: const Icon(Icons.local_dining_outlined),
              onPressed: () =>
                  showNutricaoReceitaSheet(context, receita: d.receita),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          detailAsync.maybeWhen(
            data: (d) => IconButton(
              tooltip: 'Histórico',
              icon: const Icon(Icons.history),
              onPressed: () => showHistorySheet(
                context,
                tipo: 'receita',
                id: widget.recipeId,
                titulo: d.receita.nome,
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          if (_podeEditar)
            detailAsync.maybeWhen(
              data: (d) => IconButton(
                tooltip: 'Editar receita',
                icon: const Icon(Icons.edit_outlined),
                onPressed: _busy
                    ? null
                    : () async {
                        final res = await showRecipeFormSheet(
                          context,
                          existente: d.receita,
                        );
                        if (res == null) return;
                        await _run(
                          () => ref
                              .read(recipeActionsProvider)
                              .update(widget.recipeId, res.input),
                        );
                      },
              ),
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
      floatingActionButton: _podeEditar
          ? FloatingActionButton.extended(
              onPressed: _busy ? null : _addItem,
              icon: const Icon(Icons.add),
              label: const Text('Item'),
            )
          : null,
      body: AsyncValueView<RecipeDetail>(
        value: detailAsync,
        onRetry: () =>
            ref.invalidate(recipeDetailProvider(widget.recipeId)),
        data: (d) => Column(
          children: [
            if (_busy) const LinearProgressIndicator(),
            _Header(detail: d, fmt: ref.watch(moneyFormatProvider)),
            if (d.temPendencias)
              MaterialBanner(
                content: const Text('Há linhas por ligar a um ingrediente.'),
                leading: const Icon(Icons.link_off),
                actions: const [SizedBox.shrink()],
              ),
            const Divider(height: 1),
            Expanded(
              child: d.itens.isEmpty
                  ? const Center(child: Text('Sem linhas. Usa "Item".'))
                  : ListView.separated(
                      itemCount: d.itens.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) => _itemTile(
                        d, d.itens[i], ref.watch(moneyFormatProvider)),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemTile(RecipeDetail d, ItemReceita item, MoneyFmt fmt) {
    final pct = d.percentagem(item).toStringAsFixed(1);
    final subtitle = item.pendente
        ? '${item.quantidadeG.toStringAsFixed(0)} g · vínculo pendente'
        : '${item.quantidadeG.toStringAsFixed(0)} g · $pct% · ${fmt(item.custoLinha)}';

    final tile = ListTile(
      title: Text(
        item.nome,
        style: item.pendente
            ? TextStyle(color: Theme.of(context).colorScheme.error)
            : null,
      ),
      subtitle: Text(subtitle),
      trailing: item.pendente
          ? TextButton(
              onPressed: _podeEditar ? () => _vincular(item) : null,
              child: const Text('Ligar'),
            )
          : (item.subReceitaId != null
              ? const Icon(Icons.link, size: 16)
              : null),
      onTap: _podeEditar ? () => _editQty(item) : null,
    );

    if (!_podeEditar) return tile;

    return SwipeToDelete(
      key: ValueKey(item.id),
      confirmar: () => confirmDialog(
        context,
        titulo: 'Remover linha',
        mensagem: 'Remover "${item.nome}" da receita?',
        confirmar: 'Remover',
      ),
      apagar: () => _run(
        () => ref
            .read(recipeActionsProvider)
            .removeItem(widget.recipeId, item.id),
      ),
      child: tile,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.detail, required this.fmt});
  final MoneyFmt fmt;
  final RecipeDetail detail;

  @override
  Widget build(BuildContext context) {
    Widget cell(String t, String v) => Column(
          children: [
            Text(t, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(v,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          cell('Peso', '${detail.pesoTotal.toStringAsFixed(0)} g'),
          cell('Custo (prev.)', fmt(detail.custoPreview)),
          cell('Custo/kg', fmt(detail.custoPorKg)),
        ],
      ),
    );
  }
}
