import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/help/help_content.dart';
import '../../../core/nutrition/nutri_widgets.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/help_actions.dart';
import '../../cookie_formats/application/cookie_format_providers.dart';
import '../../ingredients/application/ingredients_providers.dart';
import '../../recipes/application/recipes_providers.dart';
import '../../tech_sheets/application/tech_sheets_providers.dart';
import '../../tech_sheets/domain/tech_sheet.dart';
import '../../tech_sheets/presentation/declaracao_nutricional_sheet.dart';
import '../../tech_sheets/presentation/ficha_form_sheet.dart';
import '../application/produtos_providers.dart';
import '../domain/lista_ingredientes.dart';
import '../domain/produto_rotulo.dart';
import 'etiqueta_sheet.dart';

/// Um produto de fabrico próprio: descrição, declaração nutricional, lista de ingredientes
/// e alergénios, de forma simples e pronta a copiar/imprimir.
class ProdutoDetailScreen extends ConsumerWidget {
  const ProdutoDetailScreen({super.key, required this.fichaId});

  final String fichaId;

  Future<void> _editar(
    BuildContext context,
    WidgetRef ref,
    FichaTecnica ficha,
  ) async {
    final input = await showFichaFormSheet(context, existente: ficha);
    if (input == null) return;
    try {
      await ref.read(fichaActionsProvider).update(ficha.id, input);
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  String _textoCompleto(
    FichaTecnica f,
    ListaIngredientes? lista,
    String formato,
  ) {
    final n = f.nutri;
    final b = StringBuffer()..writeln(f.nome.toUpperCase());
    if (f.subnome.trim().isNotEmpty) b.writeln(f.subnome.trim());
    if (f.descricao.trim().isNotEmpty) b.writeln(f.descricao.trim());
    b.writeln();
    if (lista != null && !lista.vazia) {
      b.writeln('INGREDIENTES: ${lista.textoSimples}.');
      b.writeln('INGREDIENTES (resumido): ${lista.resumida().textoSimples}.');
    }
    if (f.nutri.pesoUnidadeG > 0) {
      b.writeln('Peso líquido: ${f.nutri.pesoUnidadeG.toStringAsFixed(0)} g');
    }
    final resumo = alergeniosResumo(n.alergenios, n.alergeniosTracos);
    if (resumo.isNotEmpty) b.writeln(resumo);
    if (f.conservacao.trim().isNotEmpty) {
      b.writeln(
        'Conservação: ${f.conservacao.trim().replaceFirst(RegExp(r'[.\s]+$'), '')}.',
      );
    }
    if (f.validadeDias > 0) {
      b.writeln('Validade: ${f.validadeDias} dias após o fabrico.');
    }
    b.writeln();
    if (!n.vazio) {
      b.write(
        declaracaoTexto(
          titulo: f.nome,
          por100g: n.por100g,
          porUnidade: n.porUnidade,
          pesoUnidadeG: n.pesoUnidadeG,
          alergenios: n.alergenios,
          alergeniosTracos: n.alergeniosTracos,
          completo: n.completo,
        ),
      );
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // mantém as listas carregadas (lista de ingredientes e correção em cascata)
    ref.watch(ingredientsListProvider(false));
    ref.watch(recipesListProvider(false));
    final podeEditar = ref.watch(currentPapelProvider).canEditBusiness;
    final detailAsync = ref.watch(fichaDetailProvider(fichaId));
    final ingAsync = ref.watch(produtoIngredientesProvider(fichaId));
    final formatos = ref.watch(formatosProvider).valueOrNull ?? const [];
    final ficha = detailAsync.valueOrNull?.ficha;
    String formatoNome = '';
    if (ficha != null) {
      for (final f in formatos) {
        if (f.id == ficha.formatoId) formatoNome = f.nome;
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('${Routes.techSheets}/$fichaId'),
        ),
        title: Text(ficha?.nome ?? 'Informação do produto'),
        actions: [
          if (ficha != null)
            IconButton(
              tooltip: 'Copiar tudo',
              icon: const Icon(Icons.copy_outlined),
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(
                    text: _textoCompleto(
                      ficha,
                      ingAsync.valueOrNull,
                      formatoNome,
                    ),
                  ),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Informação copiada.')),
                );
              },
            ),
          if (ficha != null)
            IconButton(
              tooltip: 'Imprimir etiqueta e informação nutricional',
              icon: const Icon(Icons.print_outlined),
              onPressed: () => showEtiquetaSheet(context, ficha: ficha),
            ),
          if (ficha != null && podeEditar)
            IconButton(
              tooltip: 'Editar a ficha (descrição, validade, conservação)',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _editar(context, ref, ficha),
            ),
          const HelpActions(topic: HelpTopic.produtos),
        ],
      ),
      body: AsyncValueView<FichaDetail>(
        value: detailAsync,
        onRetry: () => ref.invalidate(fichaDetailProvider(fichaId)),
        data: (d) => _Corpo(
          ficha: d.ficha,
          formatoNome: formatoNome,
          ingredientes: ingAsync,
          podeEditar: podeEditar,
          onEditar: () => _editar(context, ref, d.ficha),
          onRetryIngredientes: () =>
              ref.invalidate(produtoIngredientesProvider(fichaId)),
        ),
      ),
    );
  }
}

class _Corpo extends StatefulWidget {
  const _Corpo({
    required this.ficha,
    required this.formatoNome,
    required this.ingredientes,
    required this.podeEditar,
    required this.onEditar,
    required this.onRetryIngredientes,
  });

  final FichaTecnica ficha;
  final String formatoNome;
  final AsyncValue<ListaIngredientes> ingredientes;
  final bool podeEditar;
  final VoidCallback onEditar;
  final VoidCallback onRetryIngredientes;

  @override
  State<_Corpo> createState() => _CorpoState();
}

class _CorpoState extends State<_Corpo> {
  bool _resumida = false;

  @override
  Widget build(BuildContext context) {
    final ficha = widget.ficha;
    final formatoNome = widget.formatoNome;
    final ingredientes = widget.ingredientes;
    final podeEditar = widget.podeEditar;
    final onEditar = widget.onEditar;
    final onRetryIngredientes = widget.onRetryIngredientes;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final n = ficha.nutri;
    final pend = pendenciasProduto(ficha);
    final resumo = alergeniosResumo(n.alergenios, n.alergeniosTracos);

    Widget titulo(String t) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(t, style: tt.titleMedium),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (pend.isNotEmpty)
          Card(
            color: cs.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: cs.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Falta completar',
                        style: tt.titleSmall?.copyWith(
                          color: cs.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  for (final p in pend)
                    Text('• $p', style: TextStyle(color: cs.onErrorContainer)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (!nutricaoCompleta(ficha))
                        OutlinedButton(
                          onPressed: () => showDeclaracaoNutricionalSheet(
                            context,
                            ficha: ficha,
                          ),
                          child: const Text('Corrigir a nutrição'),
                        ),
                      if (podeEditar &&
                          (ficha.descricao.trim().isEmpty ||
                              ficha.validadeDias <= 0 ||
                              ficha.conservacao.trim().isEmpty))
                        OutlinedButton(
                          onPressed: onEditar,
                          child: const Text('Preencher os dados'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        Text(ficha.nome, style: tt.headlineSmall),
        if (ficha.subnome.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              ficha.subnome.trim(),
              style: tt.titleMedium?.copyWith(color: cs.primary),
            ),
          ),
        if (ficha.descricao.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(ficha.descricao.trim(), style: tt.bodyLarge),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (ficha.categoria.isNotEmpty)
              Chip(
                label: Text(ficha.categoria),
                visualDensity: VisualDensity.compact,
              ),
            if (formatoNome.isNotEmpty)
              Chip(
                label: Text(formatoNome),
                visualDensity: VisualDensity.compact,
              ),
            if (n.pesoUnidadeG > 0)
              Chip(
                label: Text(
                  'Peso líquido: ${n.pesoUnidadeG.toStringAsFixed(0)} g',
                ),
                visualDensity: VisualDensity.compact,
              ),
            if (ficha.validadeDias > 0)
              Chip(
                label: Text('Validade: ${ficha.validadeDias} dias'),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        if (ficha.conservacao.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Conservação: ${ficha.conservacao.trim()}',
              style: tt.bodyMedium,
            ),
          ),

        titulo('Declaração nutricional'),
        if (n.vazio)
          const Text('Ainda sem valores nutricionais.')
        else
          NutriTabela(
            col1Titulo: 'por 100 g',
            col1: n.por100g,
            col2Titulo: n.porUnidade != null
                ? (n.pesoUnidadeG > 0
                      ? 'unidade (${n.pesoUnidadeG.toStringAsFixed(0)} g)'
                      : 'unidade')
                : null,
            col2: n.porUnidade,
          ),
        if (!n.vazio)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Valores médios de referência, aproximados (calculados a partir dos ingredientes; produto artesanal).',
              style: tt.bodySmall,
            ),
          ),

        titulo('Ingredientes'),
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Completa')),
              ButtonSegment(value: true, label: Text('Resumida')),
            ],
            selected: {_resumida},
            onSelectionChanged: (s) => setState(() => _resumida = s.first),
          ),
        ),
        const SizedBox(height: 8),
        AsyncValueView<ListaIngredientes>(
          value: ingredientes,
          onRetry: onRetryIngredientes,
          data: (lista) {
            if (lista.vazia) {
              return const Text(
                'Sem ingredientes: a ficha ainda não tem massa/recheios com '
                'ingredientes.',
              );
            }
            final mostrar = _resumida ? lista.resumida() : lista;
            return Text.rich(
              TextSpan(
                style: tt.bodyLarge,
                children: [
                  for (final s in mostrar.segmentos)
                    TextSpan(
                      text: s.texto,
                      style: s.negrito
                          ? const TextStyle(fontWeight: FontWeight.bold)
                          : null,
                    ),
                  const TextSpan(text: '.'),
                ],
              ),
            );
          },
        ),

        titulo('Alergénios'),
        Text(
          resumo.isEmpty ? 'Nenhum alergénio registado.' : resumo,
          style: tt.bodyLarge,
        ),
        const SizedBox(height: 16),
        Text(
          'Cálculo a partir dos valores dos ingredientes (Reg. (UE) '
          '1169/2011). Confirma com os rótulos dos fornecedores. A lista de '
          'ingredientes está por ordem decrescente de peso, com os alergénios '
          'a negrito. "Completa" usa o nome de cada ingrediente (marca, %, '
          'congelado…); "Resumida" usa nomes curtos e junta variantes, para '
          'etiquetas pequenas.',
          style: tt.bodySmall,
        ),
      ],
    );
  }
}
