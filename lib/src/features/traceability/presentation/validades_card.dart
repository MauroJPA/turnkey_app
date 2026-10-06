import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/mensagem_amigavel.dart';
import '../data/lotes_repository.dart';
import '../domain/validades.dart';

/// "Validades a acabar": os lotes que vencem em breve (ou já venceram), cada
/// um com um botão para dizer que já foi todo usado, vendido ou retirado.
class ValidadesCard extends ConsumerWidget {
  const ValidadesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertas = ref.watch(alertasValidadeProvider).valueOrNull ?? const [];
    if (alertas.isEmpty) return const SizedBox.shrink();
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      color: alertas.any((a) => a.vencido)
          ? cs.errorContainer
          : cs.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Validades a acabar', style: tt.titleSmall),
            for (final a in alertas)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      a.tipo == TipoValidade.produto
                          ? Icons.cookie_outlined
                          : Icons.inventory_2_outlined,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(a.texto, style: tt.bodyMedium)),
                    TextButton(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await ref
                              .read(lotesRepositoryProvider)
                              .marcarEsgotado(a);
                          ref.invalidate(alertasValidadeProvider);
                        } on Object catch (e) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(mensagemAmigavel(e))),
                          );
                        }
                      },
                      child: Text(
                        a.tipo == TipoValidade.produto
                            ? 'Vendido/retirado'
                            : 'Já usado',
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
