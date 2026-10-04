import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_user.dart';
import '../application/inventory_providers.dart';
import '../domain/stock_item.dart';
import 'stock_sheets.dart';

/// O stock de um item numa lista (ingredientes, limpeza e insumos): quanto há
/// (a vermelho se está abaixo do mínimo). Toca para dar entrada/saída; toque
/// longo para ver o histórico.
class StockBadge extends ConsumerWidget {
  const StockBadge({super.key, required this.tipo, required this.id});

  final StockTipo tipo;
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(stockPorItemProvider)['${tipo.name}:$id'];
    if (item == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final podeEditar = ref.watch(currentPapelProvider).canEditBusiness;
    final baixo = item.stockBaixo;
    final cor = baixo ? cs.onErrorContainer : cs.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => podeEditar
              ? showAjusteStockSheet(context, item)
              : showHistoricoStockSheet(context, item),
          onLongPress: () => showHistoricoStockSheet(context, item),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: baixo ? cs.errorContainer : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  baixo ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
                  size: 14,
                  color: cor,
                ),
                const SizedBox(width: 4),
                Text(
                  baixo
                      ? 'Stock ${item.quantidadeLabel()} (mín. '
                            '${item.minimo.toStringAsFixed(item.minimo % 1 == 0 ? 0 : 1)})'
                      : 'Stock ${item.quantidadeLabel()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: cor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
