import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/async_value_view.dart';
import '../application/recipes_providers.dart';
import '../domain/recipe.dart';

/// Abre uma folha para escolher uma receita.
///
/// Por defeito mostra só produtos de fabrico próprio (`publicarComoIngrediente`),
/// com um interruptor para ver todas. Passa [categoria] para limitar a uma
/// categoria (ex.: recheios). Devolve a [Receita] escolhida ou `null`.
Future<Receita?> showRecipePickerSheet(
  BuildContext context, {
  bool soFabricoProprio = true,
  CategoriaReceita? categoria,
}) {
  return showModalBottomSheet<Receita>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _RecipePicker(
      soFabricoProprio: soFabricoProprio,
      categoria: categoria,
    ),
  );
}

class _RecipePicker extends ConsumerStatefulWidget {
  const _RecipePicker({required this.soFabricoProprio, this.categoria});

  final bool soFabricoProprio;
  final CategoriaReceita? categoria;

  @override
  ConsumerState<_RecipePicker> createState() => _RecipePickerState();
}

class _RecipePickerState extends ConsumerState<_RecipePicker> {
  String _q = '';
  late bool _soFabricoProprio = widget.soFabricoProprio;

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
                    final mc = widget.categoria == null ||
                        r.categoria == widget.categoria;
                    return mq && mf && mc;
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
