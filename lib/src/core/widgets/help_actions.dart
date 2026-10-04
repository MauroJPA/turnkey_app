import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/feedback/application/nota_pagina_providers.dart';
import '../../features/feedback/data/suggestion_repository.dart';
import '../../features/feedback/presentation/notas_pagina_sheet.dart';
import '../errors/mensagem_amigavel.dart';
import '../help/help_content.dart';

/// Botão único do `AppBar` de qualquer página: ajuda, notas da equipa e
/// sugestão/erro — tudo atrás de um só ícone, para não encher a barra de
/// ícones com 3 botões pouco usados.
class HelpActions extends ConsumerWidget {
  const HelpActions({super.key, required this.topic});

  final HelpTopic topic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final porResolver =
        ref.watch(notasPorResolverProvider(topic.name)).valueOrNull ?? 0;
    return IconButton(
      icon: Badge(
        label: Text('$porResolver'),
        isLabelVisible: porResolver > 0,
        child: const Icon(Icons.help_outline),
      ),
      tooltip: 'Ajuda, notas e sugestões',
      onPressed: () => _abrirMenu(context, ref, topic, porResolver),
    );
  }
}

void _abrirMenu(
  BuildContext context,
  WidgetRef ref,
  HelpTopic topic,
  int porResolver,
) {
  final entry = helpContent[topic];
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (entry != null) ...[
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.titulo,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final p in entry.paragrafos)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  '),
                        Expanded(
                          child: Text(
                            p,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 24),
              ],
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Badge(
                  label: Text('$porResolver'),
                  isLabelVisible: porResolver > 0,
                  child: const Icon(Icons.sticky_note_2_outlined),
                ),
                title: const Text('Notas desta página'),
                subtitle: const Text('Para a equipa ver e resolver'),
                onTap: () {
                  Navigator.pop(context);
                  mostrarNotasPagina(context, pagina: topic.name);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.feedback_outlined),
                title: const Text('Sugestão ou reportar erro'),
                subtitle: const Text('Vai para a equipa de desenvolvimento'),
                onTap: () {
                  Navigator.pop(context);
                  _abrirSugestao(context, ref, topic);
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _abrirSugestao(
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
                        ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
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
