import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/formatting/money_provider.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/help_actions.dart';
import '../application/numeros_magicos_providers.dart';
import '../domain/numeros_magicos.dart';
import '../domain/periodo.dart';

/// "Números mágicos": a partir de quanto vendido tudo já está pago e o
/// resto é lucro. Junta custos reais (fixos, variáveis, depreciação de
/// equipamentos) com os percentuais de imposto/CMV de Configurações.
class NumerosMagicosScreen extends ConsumerStatefulWidget {
  const NumerosMagicosScreen({super.key});

  @override
  ConsumerState<NumerosMagicosScreen> createState() =>
      _NumerosMagicosScreenState();
}

class _NumerosMagicosScreenState extends ConsumerState<NumerosMagicosScreen> {
  late Periodo _periodo = Periodo.semanaAtual();

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(numerosMagicosProvider(_periodo));
    final fmt = ref.watch(moneyFormatProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
        title: const Text('Números mágicos'),
        actions: const [HelpActions(topic: HelpTopic.numerosMagicos)],
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
            child: AsyncValueView<NumerosMagicos>(
              value: async,
              onRetry: () => ref.invalidate(numerosMagicosProvider(_periodo)),
              data: (n) => _corpo(context, n, fmt),
            ),
          ),
        ],
      ),
    );
  }

  Widget _corpo(BuildContext context, NumerosMagicos n, MoneyFmt fmt) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final semMargem = n.vendaMinimaMensal == null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Custos reais mensais', style: tt.titleMedium),
                const SizedBox(height: 8),
                _linha(context, 'Custos fixos', fmt(n.custosFixosMensal)),
                _linha(
                    context, 'Custos variáveis', fmt(n.custosVariaveisMensal)),
                _linha(context, 'Depreciação de equipamentos',
                    fmt(n.depreciacaoMensal)),
                const Divider(height: 20),
                _linha(context, 'Total', fmt(n.custosReaisMensais),
                    destaque: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Percentuais (Configurações → Percentuais de custo)',
                    style: tt.titleMedium),
                const SizedBox(height: 8),
                _linha(context, 'Imposto',
                    '${n.impostoPercent.toStringAsFixed(1)}%'),
                _linha(context, 'CMV (matéria-prima)',
                    '${n.cmvPercent.toStringAsFixed(1)}%'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (semMargem)
          Card(
            color: cs.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Imposto + CMV somam ${(n.impostoPercent + n.cmvPercent).toStringAsFixed(1)}% '
                '— não há margem livre para cobrir os custos com estes '
                'percentuais. Revê os Percentuais de custo em Configurações.',
                style: TextStyle(color: cs.onErrorContainer),
              ),
            ),
          )
        else ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Venda mínima', style: tt.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Cobre os custos reais + imposto + CMV — a partir daqui, '
                    'tudo o que vender a mais é lucro.',
                    style: tt.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  _linha(context, 'Por mês', fmt(n.vendaMinimaMensal!),
                      destaque: true),
                  _linha(context, 'Por dia (${n.diasUteisMes} dias)',
                      fmt(n.vendaMinimaDiaria!)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('${n.periodo.label}: como vai indo', style: tt.titleMedium),
                  const SizedBox(height: 8),
                  _linha(context, 'Vendido no período', fmt(n.receitaPeriodo)),
                  _linha(context, 'Mínimo para este período',
                      fmt(n.vendaMinimaDoPeriodo!)),
                  const Divider(height: 20),
                  _linha(
                    context,
                    n.faltaParaMinimo! > 0
                        ? 'Falta vender para bater o mínimo'
                        : 'Já passou o mínimo — lucro puro',
                    fmt(n.faltaParaMinimo!.abs()),
                    destaque: true,
                    cor: n.faltaParaMinimo! > 0 ? cs.error : cs.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _linha(
    BuildContext context,
    String label,
    String valor, {
    bool destaque = false,
    Color? cor,
  }) {
    final style = destaque
        ? Theme.of(context).textTheme.titleSmall
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style?.copyWith(color: cor)),
          Text(valor,
              style:
                  style?.copyWith(fontWeight: FontWeight.bold, color: cor)),
        ],
      ),
    );
  }
}
