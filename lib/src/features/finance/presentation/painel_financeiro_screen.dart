import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/formatting/money_provider.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/help_actions.dart';
import '../application/resumo_financeiro_providers.dart';
import '../domain/periodo.dart';
import '../domain/resumo_financeiro.dart';

class PainelFinanceiroScreen extends ConsumerStatefulWidget {
  const PainelFinanceiroScreen({super.key});

  @override
  ConsumerState<PainelFinanceiroScreen> createState() =>
      _PainelFinanceiroScreenState();
}

class _PainelFinanceiroScreenState
    extends ConsumerState<PainelFinanceiroScreen> {
  late Periodo _periodo = Periodo.semanaAtual();

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(comparacaoFinanceiraProvider(_periodo));
    final fmt = ref.watch(moneyFormatProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
        title: const Text('Painel financeiro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.description_outlined),
            tooltip: 'Ver DRE',
            onPressed: () => context.push(Routes.dre),
          ),
          const HelpActions(topic: HelpTopic.painelFinanceiro),
        ],
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
            child: AsyncValueView<ComparacaoFinanceira>(
              value: async,
              onRetry: () =>
                  ref.invalidate(comparacaoFinanceiraProvider(_periodo)),
              data: (comp) => _corpo(context, comp, fmt),
            ),
          ),
        ],
      ),
    );
  }

  Widget _corpo(BuildContext context, ComparacaoFinanceira comp, MoneyFmt fmt) {
    final r = comp.atual;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (r.numVendas == 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Sem vendas neste período.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        Row(
          children: [
            Expanded(
              child: _Cartao(
                titulo: 'Entrada (vendas)',
                valor: fmt(r.receita),
                variacaoPercent: comp.variacaoReceitaPercent,
                destaque: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Cartao(
                titulo: 'Lucro líquido',
                valor: fmt(r.lucroLiquido),
                variacaoPercent: comp.variacaoLucroPercent,
                cor: r.lucroLiquido >= 0
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Saída', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _linha(context, 'Custo dos produtos vendidos', fmt(r.custoProdutos)),
                _linha(context, 'Custos fixos (${r.periodo.label.toLowerCase()})',
                    fmt(r.custosFixos)),
                if (r.custosVariaveis > 0)
                  _linha(context, 'Custos variáveis', fmt(r.custosVariaveis)),
                if (r.depreciacaoMensal > 0)
                  _linha(context, 'Depreciação de equipamentos',
                      fmt(r.depreciacaoMensal)),
                const Divider(height: 20),
                _linha(context, 'Lucro bruto', fmt(r.lucroBruto), destaque: true),
                _linha(
                  context,
                  'Margem líquida',
                  '${r.margemLiquidaPercent.toStringAsFixed(1)}%',
                ),
              ],
            ),
          ),
        ),
        if (r.numLinhasSemFicha > 0) ...[
          const SizedBox(height: 12),
          Text(
            '⚠ ${r.numLinhasSemFicha} linha(s) de venda sem produto identificado — '
            'o custo dessas linhas não entra no cálculo (fica sobrestimado).',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          ),
        ],
        if (r.quebra.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Distribuição teórica do valor vendido',
              style: Theme.of(context).textTheme.titleMedium),
          Text(
            'Com base nas percentagens atuais (Configurações → Percentuais de '
            'custo) — mostra para onde o dinheiro deveria ir, não os custos '
            'reais acima.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  for (final e in r.quebra.entries)
                    _linha(context, e.key, fmt(e.value)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _linha(BuildContext context, String label, String valor,
      {bool destaque = false}) {
    final style = destaque
        ? Theme.of(context).textTheme.titleSmall
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(valor, style: style?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _Cartao extends StatelessWidget {
  const _Cartao({
    required this.titulo,
    required this.valor,
    this.variacaoPercent,
    this.destaque = false,
    this.cor,
  });

  final String titulo;
  final String valor;
  final double? variacaoPercent;
  final bool destaque;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              valor,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: cor ?? (destaque ? cs.primary : null),
                  ),
            ),
            if (variacaoPercent != null) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    variacaoPercent! >= 0
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    size: 14,
                    color: variacaoPercent! >= 0 ? cs.primary : cs.error,
                  ),
                  Text(
                    '${variacaoPercent!.abs().toStringAsFixed(0)}% vs. período anterior',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: variacaoPercent! >= 0 ? cs.primary : cs.error,
                        ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
