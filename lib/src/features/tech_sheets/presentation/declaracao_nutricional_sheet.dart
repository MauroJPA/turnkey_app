import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ingredients/application/ingredients_providers.dart';
import '../../ingredients/presentation/nutricao_sheet.dart';
import '../../recipes/application/recipes_providers.dart';
import '../../recipes/presentation/corrigir_nutri.dart';
import '../../recipes/presentation/nutricao_receita_sheet.dart';
import '../application/tech_sheets_providers.dart';
import '../domain/tech_sheet.dart';

/// Ajuda a completar a nutrição de uma ficha: lista os ingredientes (ou
/// massas) sem dados e leva, em cascata, ao sítio onde se preenchem. A
/// informação já pronta (tabela, ingredientes, alergénios, etiqueta) está na
/// "Informação do produto" da ficha.
Future<void> showDeclaracaoNutricionalSheet(
  BuildContext context, {
  required FichaTecnica ficha,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
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
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

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
            Text('Completar a nutrição', style: tt.titleLarge),
            Text(ficha.nome, style: tt.bodySmall),
            const SizedBox(height: 12),
            if (!n.vazio && n.completo)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('A nutrição desta ficha está completa.'),
              )
            else if (n.semDados.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Ainda sem valores. Preenche a nutrição dos ingredientes '
                  'usados nas receitas desta ficha.',
                ),
              )
            else ...[
              Text(
                n.vazio
                    ? 'Sem valores porque estes ingredientes ainda não têm '
                          'nutrição. Toca para preencher (vai em cascata pelas '
                          'massas e ingredientes):'
                    : 'Valores incompletos — toca para preencher a nutrição de:',
                style: TextStyle(color: cs.error),
              ),
              for (final sd in n.semDados)
                InkWell(
                  onTap: () => _corrigir(sd),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, size: 18),
                        const SizedBox(width: 12),
                        Expanded(child: Text(sd.nome)),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
