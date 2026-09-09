import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/nutrition/nutri_widgets.dart';
import '../domain/tech_sheet.dart';

Future<void> showDeclaracaoNutricionalSheet(
  BuildContext context, {
  required FichaTecnica ficha,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _Sheet(ficha: ficha),
  );
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.ficha});
  final FichaTecnica ficha;

  @override
  Widget build(BuildContext context) {
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
            if (n.vazio)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Ainda sem valores. Preenche a nutrição dos ingredientes '
                  'usados nas receitas desta ficha.',
                ),
              )
            else ...[
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
                  'Valores incompletos — sem dados de: '
                  '${n.semDados.take(6).join(', ')}'
                  '${n.semDados.length > 6 ? '…' : ''}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
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
