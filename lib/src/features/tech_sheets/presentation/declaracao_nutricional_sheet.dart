import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nutrition/nutri_widgets.dart';
import '../../ingredients/application/ingredients_providers.dart';
import '../../ingredients/presentation/nutricao_sheet.dart';
import '../../recipes/application/recipes_providers.dart';
import '../../recipes/presentation/corrigir_nutri.dart';
import '../../recipes/presentation/nutricao_receita_sheet.dart';
import '../application/tech_sheets_providers.dart';
import '../domain/tech_sheet.dart';

Future<void> showDeclaracaoNutricionalSheet(
  BuildContext context, {
  required FichaTecnica ficha,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useRootNavigator: true,
    useSafeArea: true,
    builder: (_) => _Sheet(ficha: ficha),
  );
}

class _Sheet extends ConsumerStatefulWidget {
  const _Sheet({required this.ficha});
  final FichaTecnica ficha;

  @override
  ConsumerState<_Sheet> createState() => _SheetState();
}

class _SheetState extends ConsumerState<_Sheet> {
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
      abrirReceita: (r) => showNutricaoReceitaSheet(context, receita: r),
    );
    if (!mounted) return;
    ref.invalidate(fichaDetailProvider(widget.ficha.id));
    ref.invalidate(ingredientsListProvider);
    ref.invalidate(recipesListProvider);
  }

  @override
  Widget build(BuildContext context) {
    // mantém as listas carregadas para o drill-in em cascata (_corrigir).
    ref.watch(ingredientsListProvider(false));
    ref.watch(recipesListProvider(false));
    final ficha =
        ref.watch(fichaDetailProvider(widget.ficha.id)).valueOrNull?.ficha ??
            widget.ficha;
    final n = ficha.nutri;
    final porUnidade = n.porUnidade;
    final resumo = alergeniosResumo(n.alergenios, n.alergeniosTracos);

    final texto = declaracaoTexto(
      titulo: ficha.nome,
      por100g: n.por100g,
      porUnidade: porUnidade,
      pesoUnidadeG: n.pesoUnidadeG,
      alergenios: n.alergenios,
      alergeniosTracos: n.alergeniosTracos,
      completo: n.completo,
    );

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
            Row(
              children: [
                Expanded(
                  child: Text('Declaração nutricional',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                if (!n.vazio)
                  TextButton.icon(
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copiar'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: texto));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Declaração copiada.')),
                      );
                    },
                  ),
              ],
            ),
            Text(ficha.nome, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            if (n.vazio && n.semDados.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Ainda sem valores. Preenche a nutrição dos ingredientes '
                  'usados nas receitas desta ficha.',
                ),
              )
            else ...[
              if (!n.vazio)
                NutriTabela(
                  col1Titulo: 'por 100 g',
                  col1: n.por100g,
                  col2Titulo: porUnidade != null
                      ? (n.pesoUnidadeG > 0
                          ? 'unidade (${n.pesoUnidadeG.toStringAsFixed(0)} g)'
                          : 'unidade')
                      : null,
                  col2: porUnidade,
                ),
              if (!n.completo) ...[
                const SizedBox(height: 8),
                Text(
                  n.vazio
                      ? 'Sem valores porque estes ingredientes ainda não têm '
                          'nutrição. Toca para preencher (vai em cascata pelas '
                          'massas e ingredientes):'
                      : 'Valores incompletos — toca para preencher a nutrição de:',
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
                const SizedBox(height: 12),
                Text('Alergénios',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(resumo),
              ],
              const SizedBox(height: 8),
              Text(
                'Cálculo a partir dos valores dos ingredientes '
                '(Reg. (UE) 1169/2011). Confirma com os rótulos.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
