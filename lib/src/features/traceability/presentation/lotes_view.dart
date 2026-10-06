import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/widgets/async_value_view.dart';
import '../data/lotes_repository.dart';
import '../domain/lote.dart';
import 'novo_lote_sheet.dart';
import 'validades_card.dart';

/// Lotes de produção (rastreabilidade): a lista dos que já registaste e o
/// botão para criar um novo. Cada lote tem uma etiqueta com QR e a sua página.
class LotesView extends ConsumerStatefulWidget {
  const LotesView({super.key});

  @override
  ConsumerState<LotesView> createState() => _LotesViewState();
}

class _LotesViewState extends ConsumerState<LotesView> {
  String _q = '';

  static String _data(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _novo() async {
    final l = await showNovoLoteSheet(context);
    if (l != null && mounted) context.go(Routes.lote(l.codigo));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(lotesRecentesProvider);
    final podeEditar = ref.watch(currentPapelProvider) != Papel.viewer;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Stack(
      children: [
        AsyncValueView<List<LoteProducao>>(
          value: async,
          onRetry: () => ref.invalidate(lotesRecentesProvider),
          data: (todos) {
            final q = _q.trim().toLowerCase();
            final lista = [
              for (final l in todos)
                if (q.isEmpty ||
                    l.codigo.toLowerCase().contains(q) ||
                    l.fichaNome.toLowerCase().contains(q))
                  l,
            ];
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(lotesRecentesProvider),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  const ValidadesCard(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Text(
                      'Cada lote guarda o que produziste e os lotes dos '
                      'ingredientes usados (rastreabilidade — Reg. 178/2002). '
                      'A etiqueta leva um QR que abre esta informação.',
                      style: tt.bodySmall,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: TextField(
                      onChanged: (v) => setState(() => _q = v),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Procurar por lote ou produto',
                        isDense: true,
                      ),
                    ),
                  ),
                  if (lista.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          todos.isEmpty
                              ? 'Ainda sem lotes. Toca em "Novo lote" quando '
                                    'fizeres uma produção.'
                              : 'Nenhum lote corresponde.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  for (final l in lista)
                    Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 3,
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.qr_code_2),
                        title: Text(
                          l.codigo,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          [
                            l.fichaNome,
                            _data(l.dataProducao),
                            if (l.quantidade > 0)
                              '${l.quantidade.toStringAsFixed(0)} un',
                          ].join(' · '),
                        ),
                        trailing: l.semLote > 0
                            ? Tooltip(
                                message: '${l.semLote} ingrediente(s) sem lote',
                                child: Icon(
                                  Icons.warning_amber_rounded,
                                  color: cs.error,
                                ),
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: () => context.go(Routes.lote(l.codigo)),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        if (podeEditar)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: _novo,
              icon: const Icon(Icons.add),
              label: const Text('Novo lote'),
            ),
          ),
      ],
    );
  }
}
