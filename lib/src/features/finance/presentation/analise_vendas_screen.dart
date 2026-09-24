import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/formatting/money_provider.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/help_actions.dart';
import '../application/analise_vendas_providers.dart';
import '../domain/analise_vendas.dart';
import '../domain/periodo.dart';

/// Sabores mais vendidos, margem real por ficha técnica e tendência face ao
/// período anterior — a análise de vendas do painel financeiro.
class AnaliseVendasScreen extends ConsumerStatefulWidget {
  const AnaliseVendasScreen({super.key});

  @override
  ConsumerState<AnaliseVendasScreen> createState() =>
      _AnaliseVendasScreenState();
}

class _AnaliseVendasScreenState extends ConsumerState<AnaliseVendasScreen> {
  late Periodo _periodo = Periodo.semanaAtual();

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(analiseVendasProvider(_periodo));
    final fmt = ref.watch(moneyFormatProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.sales),
        ),
        title: const Text('Análise de vendas'),
        actions: const [HelpActions(topic: HelpTopic.analiseVendas)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SegmentedButton<Periodo>(
              segments: [
                for (final p in Periodo.presets())
                  ButtonSegment(value: p, label: Text(p.label)),
              ],
              selected: {_periodo},
              onSelectionChanged: (s) => setState(() => _periodo = s.first),
            ),
          ),
          Expanded(
            child: AsyncValueView<AnaliseVendas>(
              value: async,
              onRetry: () => ref.invalidate(analiseVendasProvider(_periodo)),
              data: (a) => _corpo(context, a, fmt),
            ),
          ),
        ],
      ),
    );
  }

  Widget _corpo(BuildContext context, AnaliseVendas a, MoneyFmt fmt) {
    final comFicha = a.porFicha.where((v) => v.temFicha).toList();
    if (a.porFicha.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'Sem vendas neste período.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    final maisVendido = comFicha.isEmpty
        ? null
        : comFicha.reduce((x, y) => y.quantidade > x.quantidade ? y : x);
    final comMargem = comFicha.where((v) => v.receita > 0).toList();
    final maiorMargem = comMargem.isEmpty
        ? null
        : comMargem.reduce((x, y) => y.margemPercent > x.margemPercent ? y : x);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (maisVendido != null || maiorMargem != null)
          Row(
            children: [
              if (maisVendido != null)
                Expanded(
                  child: _Destaque(
                    titulo: 'Mais vendido',
                    nome: maisVendido.nome,
                    valor: '${_qtd(maisVendido.quantidade)} un.',
                  ),
                ),
              if (maisVendido != null && maiorMargem != null)
                const SizedBox(width: 12),
              if (maiorMargem != null)
                Expanded(
                  child: _Destaque(
                    titulo: 'Maior margem',
                    nome: maiorMargem.nome,
                    valor: '${maiorMargem.margemPercent.toStringAsFixed(0)}%',
                  ),
                ),
            ],
          ),
        const SizedBox(height: 16),
        Text('Por sabor', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                for (final v in a.porFicha) _linha(context, a, v, fmt),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _linha(
      BuildContext context, AnaliseVendas a, VendaPorFicha v, MoneyFmt fmt) {
    final tendencia = a.tendenciaPercent(v);
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              v.nome,
              style: v.temFicha
                  ? null
                  : Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontStyle: FontStyle.italic, color: cs.outline),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text('${_qtd(v.quantidade)} un.',
                textAlign: TextAlign.right),
          ),
          Expanded(
            flex: 2,
            child: Text(fmt(v.receita), textAlign: TextAlign.right),
          ),
          Expanded(
            flex: 2,
            child: Text(
              v.temFicha ? '${v.margemPercent.toStringAsFixed(0)}%' : '—',
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 44,
            child: tendencia == null
                ? null
                : Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tendencia >= 0
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 14,
                        color: tendencia >= 0 ? cs.primary : cs.error,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String _qtd(double q) =>
      q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(1);
}

class _Destaque extends StatelessWidget {
  const _Destaque({required this.titulo, required this.nome, required this.valor});

  final String titulo;
  final String nome;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(nome,
                style: Theme.of(context).textTheme.titleSmall,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(valor,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: Theme.of(context).colorScheme.primary)),
          ],
        ),
      ),
    );
  }
}
