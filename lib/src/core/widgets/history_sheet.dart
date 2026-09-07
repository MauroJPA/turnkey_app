import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/history_repository.dart';
import '../formatting/dates.dart';
import 'async_value_view.dart';

/// Folha com o histórico de recálculos de uma entidade.
/// [tipo] é 'ingrediente' | 'receita' | 'ficha'.
void showHistorySheet(
  BuildContext context, {
  required String tipo,
  required String id,
  required String titulo,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _HistorySheet(tipo: tipo, id: id, titulo: titulo),
  );
}

class _HistorySheet extends ConsumerWidget {
  const _HistorySheet({
    required this.tipo,
    required this.id,
    required this.titulo,
  });

  final String tipo;
  final String id;
  final String titulo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(historyProvider((tipo: tipo, id: id)));
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Histórico · $titulo',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: AsyncValueView<List<HistoryEntry>>(
              value: async,
              onRetry: () =>
                  ref.invalidate(historyProvider((tipo: tipo, id: id))),
              data: (entries) => entries.isEmpty
                  ? const Center(child: Text('Sem registos.'))
                  : ListView.separated(
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) => ListTile(
                        dense: true,
                        title: Text(entries[i].descricao),
                        subtitle: Text(
                          formatDateTimeShort(entries[i].created),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
