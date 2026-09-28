import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/feedback/application/nota_pagina_providers.dart';
import '../../features/feedback/data/suggestion_repository.dart';
import '../../features/feedback/presentation/notas_pagina_sheet.dart';
import '../help/help_content.dart';
import 'help_button.dart';

/// Ações para o `AppBar` de qualquer página: notas de equipa, enviar
/// sugestão/erro e ajuda. Substitui o `HelpButton` sozinho.
class HelpActions extends ConsumerWidget {
  const HelpActions({super.key, required this.topic});

  final HelpTopic topic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final porResolver = ref
        .watch(notasPorResolverProvider(topic.name))
        .valueOrNull;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Badge(
            label: Text('$porResolver'),
            isLabelVisible: (porResolver ?? 0) > 0,
            child: const Icon(Icons.sticky_note_2_outlined),
          ),
          tooltip: 'Notas desta página (para a equipa)',
          onPressed: () => mostrarNotasPagina(context, pagina: topic.name),
        ),
        IconButton(
          icon: const Icon(Icons.feedback_outlined),
          tooltip: 'Sugerir melhoria / reportar erro',
          onPressed: () => _abrir(context, ref, topic),
        ),
        HelpButton(topic: topic),
      ],
    );
  }
}

Future<void> _abrir(
  BuildContext context,
  WidgetRef ref,
  HelpTopic topic,
) async {
  final ctrl = TextEditingController();
  var enviando = false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Sugestão ou erro'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Descreve o que correu mal ou o que podia ser melhor nesta '
              'página. Vai para a equipa de desenvolvimento.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              minLines: 3,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'A tua nota…',
                border: OutlineInputBorder(),
              ),
              // sem isto, "Enviar" ficava sempre desativado: o diálogo só
              // volta a construir (e a reler ctrl.text) quando algo chama
              // setState — escrever no campo, por si só, não chamava.
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: enviando ? null : () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: enviando || ctrl.text.trim().isEmpty
                ? null
                : () async {
                    setState(() => enviando = true);
                    try {
                      await ref
                          .read(suggestionRepositoryProvider)
                          .enviar(pagina: topic.name, texto: ctrl.text);
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } on Object catch (e) {
                      if (ctx.mounted) {
                        setState(() => enviando = false);
                        ScaffoldMessenger.of(
                          ctx,
                        ).showSnackBar(SnackBar(content: Text('$e')));
                      }
                    }
                  },
            child: enviando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Enviar'),
          ),
        ],
      ),
    ),
  );
  if (ok == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Obrigado! Sugestão enviada.')),
    );
  }
}
