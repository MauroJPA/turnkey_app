import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/download/web_download.dart';
import '../../../core/formatting/money_provider.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/help_actions.dart';
import '../../finance/domain/periodo.dart';
import '../../finance/presentation/seletor_periodo.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../inventory/domain/compra_registada.dart';
import '../../sales/domain/venda.dart' show ymd;

typedef IntervaloCompras = ({DateTime desde, DateTime ate});

/// As compras que deram entrada no stock no período.
final comprasPeriodoProvider = FutureProvider.autoDispose
    .family<List<CompraRegistada>, IntervaloCompras>(
      (ref, i) => ref
          .watch(inventoryRepositoryProvider)
          .compras(desde: i.desde, ate: i.ate),
    );

/// "O que comprei": relatório das compras registadas (dar o visto na lista de
/// compras e aplicar faturas), por dia, fornecedor ou produto.
class ComprasRelatorioScreen extends ConsumerStatefulWidget {
  const ComprasRelatorioScreen({super.key});

  @override
  ConsumerState<ComprasRelatorioScreen> createState() =>
      _ComprasRelatorioScreenState();
}

class _ComprasRelatorioScreenState
    extends ConsumerState<ComprasRelatorioScreen> {
  Periodo _periodo = Periodo.semanaAtual();
  AgruparCompras _como = AgruparCompras.dia;

  void _descarregar(List<CompraRegistada> compras) {
    final linhas = <List<String>>[
      ['data', 'produto', 'quantidade', 'unidade', 'fornecedor', 'origem', 'custo_estimado'],
      for (final c in compras)
        [
          ymd(c.data),
          c.nome,
          c.quantidade.toString(),
          c.unidade,
          c.fornecedor,
          c.origem,
          c.custoEstimado == null ? '' : c.custoEstimado!.toStringAsFixed(2),
        ],
    ];
    final csv = const ListToCsvConverter(eol: '\r\n').convert(linhas);
    baixarFicheiro(
      'compras-${ymd(_periodo.desde)}_${ymd(_periodo.ate)}.csv',
      utf8.encode(csv),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final fmt = ref.watch(moneyFormatProvider);
    final async = ref.watch(
      comprasPeriodoProvider((desde: _periodo.desde, ate: _periodo.ate)),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.shopping),
        ),
        title: const Text('O que comprei'),
        actions: [
          IconButton(
            tooltip: 'Descarregar CSV',
            icon: const Icon(Icons.download_outlined),
            onPressed: async.valueOrNull == null || async.value!.isEmpty
                ? null
                : () => _descarregar(async.value!),
          ),
          const HelpActions(topic: HelpTopic.comprasRelatorio),
        ],
      ),
      body: Column(
        children: [
          SeletorPeriodo(
            periodo: _periodo,
            onChanged: (p) => setState(() => _periodo = p),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: SegmentedButton<AgruparCompras>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: AgruparCompras.dia, label: Text('Por dia')),
                ButtonSegment(
                  value: AgruparCompras.fornecedor,
                  label: Text('Fornecedor'),
                ),
                ButtonSegment(
                  value: AgruparCompras.produto,
                  label: Text('Produto'),
                ),
              ],
              selected: {_como},
              onSelectionChanged: (s) => setState(() => _como = s.first),
            ),
          ),
          Expanded(
            child: AsyncValueView<List<CompraRegistada>>(
              value: async,
              onRetry: () => ref.invalidate(comprasPeriodoProvider),
              data: (compras) {
                if (compras.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Sem compras registadas neste período. Aparecem aqui '
                        'quando dás o visto na lista de compras ou aplicas '
                        'uma fatura.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                final grupos = agruparCompras(compras, _como);
                final total = compras.fold<double>(
                  0,
                  (s, c) => s + (c.custoEstimado ?? 0),
                );
                final semCusto = compras
                    .where((c) => c.custoEstimado == null)
                    .length;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Wrap(
                          spacing: 24,
                          runSpacing: 4,
                          children: [
                            _kpi('Compras', '${compras.length}', tt),
                            _kpi('Custo estimado', fmt(total), tt),
                          ],
                        ),
                      ),
                    ),
                    if (semCusto > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '$semCusto compra(s) sem custo estimado (sem preço '
                          'definido). O custo é a quantidade × o preço atual '
                          'do produto — para o valor exato, vê as Faturas.',
                          style: tt.bodySmall,
                        ),
                      ),
                    for (final g in grupos) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: Text(g.titulo, style: tt.titleSmall)),
                          Text(
                            fmt(g.custoEstimado),
                            style: tt.titleSmall?.copyWith(color: cs.primary),
                          ),
                        ],
                      ),
                      for (final c in g.itens)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(
                            _como == AgruparCompras.produto
                                ? '${c.data.day.toString().padLeft(2, '0')}/'
                                      '${c.data.month.toString().padLeft(2, '0')}'
                                : c.nome,
                          ),
                          subtitle: Text(
                            [
                              if (_como != AgruparCompras.fornecedor &&
                                  c.fornecedor.isNotEmpty)
                                c.fornecedor,
                              if (c.origem.isNotEmpty) c.origem,
                            ].join(' · '),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                c.quantidadeTexto,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (c.custoEstimado != null)
                                Text(fmt(c.custoEstimado!), style: tt.bodySmall),
                            ],
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpi(String k, String v, TextTheme tt) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(k, style: tt.bodySmall),
      Text(v, style: tt.titleLarge),
    ],
  );
}
