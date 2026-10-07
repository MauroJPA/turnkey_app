import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/prefs_locais.dart';
import '../data/arranque_repository.dart';
import '../domain/arranque.dart';

const _chaveDispensado = 'arranque_dispensado';

/// "Primeiros passos": o que falta configurar, com progresso e atalhos. Só a
/// administração o vê; some sozinho quando está tudo feito (ou se for
/// dispensado neste aparelho).
class ArranqueCard extends ConsumerStatefulWidget {
  const ArranqueCard({super.key});

  @override
  ConsumerState<ArranqueCard> createState() => _ArranqueCardState();
}

class _ArranqueCardState extends ConsumerState<ArranqueCard> {
  late bool _dispensado = lerPref(_chaveDispensado) == '1';
  bool _tudo = false;

  void _abrir(PassoArranque p) {
    final info = p.info;
    if (info.rota != null) {
      context.go(info.rota!);
      return;
    }
    if (info.ajuda.isNotEmpty) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(info.titulo),
          content: SelectableText(info.ajuda),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dispensado) return const SizedBox.shrink();
    final a = ref.watch(arranqueProvider).valueOrNull;
    if (a == null || a.completo) return const SizedBox.shrink();

    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final porFazer = a.porFazer;
    final visiveis = _tudo ? a.passos : porFazer.take(3).toList();

    return Card(
      margin: const EdgeInsets.only(top: 12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Primeiros passos · ${a.feitos} de ${a.total}',
                    style: tt.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Esconder',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    guardarPref(_chaveDispensado, '1');
                    setState(() => _dispensado = true);
                  },
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: a.progresso,
                  minHeight: 6,
                ),
              ),
            ),
            for (final p in visiveis)
              InkWell(
                key: ValueKey('arranque-${p.chave}'),
                borderRadius: BorderRadius.circular(8),
                onTap: p.feito ? null : () => _abrir(p),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 6, 8, 6),
                  child: Row(
                    children: [
                      Icon(
                        p.feito
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 20,
                        color: p.feito ? cs.primary : cs.outline,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.info.titulo,
                              style: tt.bodyMedium?.copyWith(
                                decoration: p.feito
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: p.feito ? cs.outline : null,
                              ),
                            ),
                            if (p.detalhe.isNotEmpty)
                              Text(
                                p.detalhe,
                                style: tt.bodySmall?.copyWith(
                                  color: cs.outline,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (!p.feito)
                        Icon(Icons.chevron_right, size: 20, color: cs.outline),
                    ],
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _tudo = !_tudo),
                child: Text(_tudo ? 'Mostrar só o que falta' : 'Ver todos'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
