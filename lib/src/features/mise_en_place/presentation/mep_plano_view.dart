import 'package:flutter/material.dart';

import '../../../core/formatting/quantities.dart';
import '../domain/mep_plano.dart';

/// O mise en place calculado: "Produzir primeiro" (massa, recheios,
/// coberturas e outros intermédios) e "Ingredientes" a pesar, com caixas para
/// ir marcando. Usado na página Mise en place e em Produzir.
class MepPlanoView extends StatelessWidget {
  const MepPlanoView({
    super.key,
    required this.plano,
    required this.feitos,
    required this.onToggle,
    required this.onAbrirIntermedio,
    this.onProduzir,
    this.busy = false,
    this.mostrarProduzir = true,
  });

  final MepPlano plano;
  final Set<String> feitos;
  final void Function(String id, bool v) onToggle;
  final void Function(MepIntermedio) onAbrirIntermedio;
  final VoidCallback? onProduzir;
  final bool busy;

  /// Esconde o botão "Produção feita" (ex.: em Produzir, onde só se planeia).
  final bool mostrarProduzir;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            [
              if (plano.fichaId.isNotEmpty && plano.unidades > 0)
                '${plano.unidades} un',
              '${plano.kg.toStringAsFixed(2)} kg de massa',
              if (plano.formato.isNotEmpty) plano.formato,
              if (plano.fichaId.isEmpty && plano.unidades > 0)
                '≈ ${plano.unidades} unidades',
              if (plano.recheio.isNotEmpty) 'recheio ${plano.recheio}',
            ].join('  ·  '),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (plano.intermedios.isNotEmpty) ...[
          Text('Produzir primeiro',
              style: Theme.of(context).textTheme.titleSmall),
          for (final it in plano.intermedios)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 3),
              child: CheckboxListTile(
                controlAffinity: ListTileControlAffinity.leading,
                value: feitos.contains('int:${it.receitaId}'),
                onChanged: (v) => onToggle('int:${it.receitaId}', v ?? false),
                title: Text(it.nome,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  it.eMassa
                      ? '${gramasParaTexto(it.gramas)} · massa'
                      : gramasParaTexto(it.gramas),
                ),
                secondary: TextButton(
                  onPressed: () => onAbrirIntermedio(it),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          const SizedBox(height: 12),
        ],
        Text('Ingredientes', style: Theme.of(context).textTheme.titleSmall),
        for (final c in plano.comprar)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 3),
            child: CheckboxListTile(
              controlAffinity: ListTileControlAffinity.leading,
              value: feitos.contains('ing:${c.ingredienteId}'),
              onChanged: (v) => onToggle('ing:${c.ingredienteId}', v ?? false),
              title: Text(c.nome, style: const TextStyle(fontSize: 16)),
              subtitle: Text(
                c.faltaStock
                    ? '${gramasParaTexto(c.gramas)} · em stock só '
                        '${gramasParaTexto(c.emStock)}'
                    : '${gramasParaTexto(c.gramas)} · em stock',
                style: TextStyle(
                  color: c.faltaStock ? cs.error : cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        if (mostrarProduzir) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onProduzir,
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.task_alt),
            label: const Text('Produção feita'),
          ),
        ],
      ],
    );
  }
}
