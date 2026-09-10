import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nutrition/nutri_widgets.dart';
import '../../ingredients/application/ingredients_providers.dart';
import '../../ingredients/domain/ingredient.dart';
import '../../ingredients/presentation/nutricao_sheet.dart';
import '../application/recipes_providers.dart';
import '../domain/recipe.dart';
import '../domain/recipe_item.dart';

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

enum _EstadoItem { ok, rever, falta, pendente }

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

  Future<void> _abrir(ItemReceita it) async {
    final recs = ref.read(recipesListProvider(false)).valueOrNull ?? const [];
    final ings =
        ref.read(ingredientsListProvider(false)).valueOrNull ?? const [];

    final subId = it.subReceitaId ??
        (it.eEspelho ? it.ingredienteEspelhoId : null);
    if (subId != null) {
      final rec = recs.where((r) => r.id == subId).firstOrNull;
      if (rec != null && rec.id != widget.receita.id) {
        await showNutricaoReceitaSheet(context, receita: rec);
      } else {
        _semRota(it.nome);
      }
    } else if (it.ingredienteId != null) {
      final ing = ings.where((i) => i.id == it.ingredienteId).firstOrNull;
      if (ing != null) {
        await showNutricaoSheet(context, ingrediente: ing);
      } else {
        _semRota(it.nome);
      }
    } else {
      _semRota(it.nome);
    }
    if (!mounted) return;
    ref.invalidate(recipeDetailProvider(widget.receita.id));
    ref.invalidate(ingredientsListProvider);
    ref.invalidate(recipesListProvider);
  }

  void _semRota(String nome) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Não consegui abrir "$nome".')),
    );
  }

  _EstadoItem _estado(
    ItemReceita it,
    List<Ingrediente> ings,
    List<Receita> recs,
  ) {
    if (it.pendente) return _EstadoItem.pendente;
    final subId = it.subReceitaId ??
        (it.eEspelho ? it.ingredienteEspelhoId : null);
    if (subId != null) {
      final rec = recs.where((r) => r.id == subId).firstOrNull;
      if (rec == null) return _EstadoItem.falta;
      return rec.nutri.completo && !rec.nutri.vazio
          ? _EstadoItem.ok
          : _EstadoItem.falta;
    }
    final ing = ings.where((i) => i.id == it.ingredienteId).firstOrNull;
    if (ing == null) return _EstadoItem.falta;
    if (ing.precisaRevisaoInsa) return _EstadoItem.rever;
    return ing.temNutri ? _EstadoItem.ok : _EstadoItem.falta;
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(recipeDetailProvider(widget.receita.id));
    final ings = ref.watch(ingredientsListProvider(false)).valueOrNull ??
        const <Ingrediente>[];
    final recs = ref.watch(recipesListProvider(false)).valueOrNull ??
        const <Receita>[];
    final receita = detailAsync.valueOrNull?.receita ?? widget.receita;
    final itens = detailAsync.valueOrNull?.itens ?? const <ItemReceita>[];
    final n = receita.nutri;
    final cozido = n.por100gCozido;
    final temPerda = receita.perdaCozeduraPct > 0 && cozido != null;
    final resumo = alergeniosResumo(n.alergenios, n.alergeniosTracos);

    final linhas = itens.where((i) => i.quantidadeG > 0).toList();
    final faltam = linhas
        .where((i) => _estado(i, ings, recs) != _EstadoItem.ok)
        .length;

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
            Text('${widget.receita.nome} · produto Gookie',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              'Calculada a partir dos ingredientes. Preenche os que faltam '
              '(cada subproduto abre os seus).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (!n.vazio)
              NutriTabela(
                col1Titulo: 'por 100 g',
                col1: n.por100g,
                col2Titulo: temPerda ? 'cozido' : null,
                col2: temPerda ? cozido : null,
              ),
            if (resumo.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(resumo, style: Theme.of(context).textTheme.bodyMedium),
            ],
            const SizedBox(height: 12),
            Text(
              faltam == 0 && !n.vazio
                  ? 'Ingredientes — tudo preenchido ✓'
                  : 'Ingredientes ($faltam a preencher):',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: faltam == 0 && !n.vazio
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                  ),
            ),
            if (linhas.isEmpty && detailAsync.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (linhas.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Esta receita ainda não tem ingredientes.'),
              )
            else
              for (final it in linhas)
                _ItemTile(
                  it: it,
                  estado: _estado(it, ings, recs),
                  onTap: _busy ? null : () => _abrir(it),
                ),
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

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.it,
    required this.estado,
    required this.onTap,
  });

  final ItemReceita it;
  final _EstadoItem estado;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ehSub = it.subReceitaId != null || it.eEspelho;
    final (IconData ic, Color cor, String txt) = switch (estado) {
      _EstadoItem.ok => (Icons.check_circle, cs.primary, 'com nutrição'),
      _EstadoItem.rever => (Icons.rule, cs.tertiary, 'escolher da INSA'),
      _EstadoItem.falta => (
          Icons.error_outline,
          cs.error,
          ehSub ? 'abrir subproduto' : 'sem nutrição',
        ),
      _EstadoItem.pendente => (
          Icons.help_outline,
          cs.onSurfaceVariant,
          'linha por definir',
        ),
    };
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(ic, size: 20, color: cor),
      title: Text(it.nome),
      subtitle: Text(
        '${ehSub ? 'Subproduto Gookie' : 'Ingrediente'} · '
        '${it.quantidadeG.toStringAsFixed(0)} g · $txt',
      ),
      trailing: estado == _EstadoItem.pendente
          ? null
          : const Icon(Icons.chevron_right),
      onTap: estado == _EstadoItem.pendente ? null : onTap,
    );
  }
}
