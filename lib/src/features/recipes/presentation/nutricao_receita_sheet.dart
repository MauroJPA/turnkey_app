import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nutrition/nutri_widgets.dart';
import '../../ingredients/application/ingredients_providers.dart';
import '../../ingredients/presentation/nutricao_sheet.dart';
import '../application/recipes_providers.dart';
import '../domain/recipe.dart';
import 'corrigir_nutri.dart';

Future<void> showNutricaoReceitaSheet(
  BuildContext context, {
  required Receita receita,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useRootNavigator: true,
    useSafeArea: true,
    builder: (_) => _Sheet(receita: receita),
  );
}

class _Sheet extends ConsumerStatefulWidget {
  const _Sheet({required this.receita});
  final Receita receita;

  @override
  ConsumerState<_Sheet> createState() => _SheetState();
}

class _SheetState extends ConsumerState<_Sheet> {
  late final _perda = TextEditingController(
    text: widget.receita.perdaCozeduraPct == 0
        ? ''
        : widget.receita.perdaCozeduraPct.toStringAsFixed(0),
  );
  bool _busy = false;

  @override
  void dispose() {
    _perda.dispose();
    super.dispose();
  }

  Future<void> _guardarPerda() async {
    final v = double.tryParse(_perda.text.replaceAll(',', '.').trim()) ?? 0;
    if (v == widget.receita.perdaCozeduraPct) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(recipeActionsProvider)
          .setPerdaCozedura(widget.receita.id, v);
      if (mounted) Navigator.pop(context);
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _corrigir(({String id, String nome}) alvo) async {
    final ings = ref.read(ingredientsListProvider(false)).valueOrNull;
    final recs = ref.read(recipesListProvider(false)).valueOrNull;
    if (ings == null || recs == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A carregar… tenta outra vez num instante.')),
      );
      return;
    }
    await corrigirNutriEmCascata(
      context,
      ings: ings,
      recs: recs,
      alvo: alvo,
      abrirIngrediente: (i) => showNutricaoSheet(context, ingrediente: i),
      abrirReceita: (r) => r.id == widget.receita.id
          ? Future.value()
          : showNutricaoReceitaSheet(context, receita: r),
    );
    if (!mounted) return;
    ref.invalidate(recipeDetailProvider(widget.receita.id));
    ref.invalidate(ingredientsListProvider);
    ref.invalidate(recipesListProvider);
  }

  @override
  Widget build(BuildContext context) {
    // mantém as listas carregadas para o drill-in em cascata (_corrigir).
    ref.watch(ingredientsListProvider(false));
    ref.watch(recipesListProvider(false));
    final receita =
        ref.watch(recipeDetailProvider(widget.receita.id)).valueOrNull?.receita ??
            widget.receita;
    final n = receita.nutri;
    final cozido = n.por100gCozido;
    final temPerda = receita.perdaCozeduraPct > 0 && cozido != null;
    final resumo = alergeniosResumo(n.alergenios, n.alergeniosTracos);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Informação nutricional',
                style: Theme.of(context).textTheme.titleLarge),
            Text(widget.receita.nome,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            if (n.vazio)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Ainda sem valores. Preenche a nutrição dos ingredientes '
                  '(botão de nutrição na lista de ingredientes).',
                ),
              )
            else ...[
              NutriTabela(
                col1Titulo: 'por 100 g',
                col1: n.por100g,
                col2Titulo: temPerda ? 'cozido' : null,
                col2: temPerda ? cozido : null,
              ),
              if (!n.completo) ...[
                const SizedBox(height: 8),
                Text(
                  'Valores incompletos — toca para preencher a nutrição de:',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
                for (final sd in n.semDados)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.error_outline, size: 18),
                    title: Text(sd.nome),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _corrigir(sd),
                  ),
              ],
              if (resumo.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(resumo,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ],
            const Divider(height: 28),
            Text('Perda de peso na cozedura',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              'A água que sai a cozer concentra os valores por 100 g de '
              'produto. Deixa a 0 se não coze.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _perda,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Perda',
                      suffixText: '%',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _busy ? null : _guardarPerda,
                  child: const Text('Guardar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
