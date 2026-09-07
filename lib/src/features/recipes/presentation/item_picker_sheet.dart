import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/async_value_view.dart';
import '../../ingredients/application/ingredients_providers.dart';
import '../application/recipes_providers.dart';

enum PickedKind { ingrediente, subReceita }

class PickedItem {
  PickedItem({
    required this.kind,
    required this.id,
    required this.nome,
    required this.quantidadeG,
  });
  final PickedKind kind;
  final String id;
  final String nome;
  final double quantidadeG;
}

/// Escolhe um ingrediente ou sub-receita e a quantidade em gramas.
/// Se [apenasVincular] for `true`, não pergunta a quantidade (devolve 0).
Future<PickedItem?> showItemPickerSheet(
  BuildContext context, {
  String? excludeRecipeId,
  bool apenasVincular = false,
}) {
  return showModalBottomSheet<PickedItem>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ItemPickerSheet(
      excludeRecipeId: excludeRecipeId,
      apenasVincular: apenasVincular,
    ),
  );
}

class _ItemPickerSheet extends ConsumerStatefulWidget {
  const _ItemPickerSheet({this.excludeRecipeId, this.apenasVincular = false});
  final String? excludeRecipeId;
  final bool apenasVincular;

  @override
  ConsumerState<_ItemPickerSheet> createState() => _ItemPickerSheetState();
}

class _ItemPickerSheetState extends ConsumerState<_ItemPickerSheet> {
  PickedKind _kind = PickedKind.ingrediente;
  String _q = '';

  Future<PickedItem?> _askQty(
      PickedKind kind, String id, String nome) async {
    if (widget.apenasVincular) {
      return PickedItem(kind: kind, id: id, nome: nome, quantidadeG: 0);
    }
    final ctrl = TextEditingController();
    final qtd = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Quantidade — $nome'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Gramas'),
          onSubmitted: (_) => Navigator.pop(
            ctx,
            double.tryParse(ctrl.text.replaceAll(',', '.')),
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
              double.tryParse(ctrl.text.replaceAll(',', '.')),
            ),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
    if (qtd == null || qtd <= 0) return null;
    return PickedItem(kind: kind, id: id, nome: nome, quantidadeG: qtd);
  }

  @override
  Widget build(BuildContext context) {
    final ingredientes = ref.watch(ingredientsListProvider(false));
    final receitas = ref.watch(recipesListProvider(false));

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            SegmentedButton<PickedKind>(
              segments: const [
                ButtonSegment(
                  value: PickedKind.ingrediente,
                  label: Text('Ingredientes'),
                ),
                ButtonSegment(
                  value: PickedKind.subReceita,
                  label: Text('Receitas'),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Procurar',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _kind == PickedKind.ingrediente
                  ? AsyncValueView(
                      value: ingredientes,
                      data: (all) {
                        final items = all
                            .where((i) => i.nome
                                .toLowerCase()
                                .contains(_q.toLowerCase()))
                            .toList();
                        return ListView(
                          children: [
                            for (final i in items)
                              ListTile(
                                title: Text(i.nome),
                                subtitle: Text(i.fornecedor),
                                onTap: () async {
                                  final r = await _askQty(
                                    PickedKind.ingrediente,
                                    i.id,
                                    i.nome,
                                  );
                                  if (r != null && context.mounted) {
                                    Navigator.pop(context, r);
                                  }
                                },
                              ),
                          ],
                        );
                      },
                    )
                  : AsyncValueView(
                      value: receitas,
                      data: (all) {
                        final items = all
                            .where((r) =>
                                r.id != widget.excludeRecipeId &&
                                r.nome
                                    .toLowerCase()
                                    .contains(_q.toLowerCase()))
                            .toList();
                        return ListView(
                          children: [
                            for (final r in items)
                              ListTile(
                                title: Text(r.nome),
                                subtitle: Text(r.categoria.label),
                                onTap: () async {
                                  final res = await _askQty(
                                    PickedKind.subReceita,
                                    r.id,
                                    r.nome,
                                  );
                                  if (res != null && context.mounted) {
                                    Navigator.pop(context, res);
                                  }
                                },
                              ),
                          ],
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
