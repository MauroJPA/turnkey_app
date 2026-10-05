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
import 'seletor_periodo.dart';

/// "Números mágicos": a partir de quanto vendido tudo já está pago e o
/// resto é lucro. Junta custos reais (fixos, variáveis, depreciação de
/// equipamentos) com os percentuais de imposto/CMV de Configurações.
class NumerosMagicosScreen extends ConsumerStatefulWidget {
  const NumerosMagicosScreen({super.key, this.embedded = false});

  /// Dentro da página Contabilidade: sem seta de voltar, título nem ajuda.
  final bool embedded;

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
      appBar: widget.embedded
          ? null
          : AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go(Routes.home),
              ),
              title: const Text('Números mágicos'),
              actions: const [HelpActions(topic: HelpTopic.numerosMagicos)],
            ),
      body: Column(
        children: [
          SeletorPeriodo(
            periodo: _periodo,
            onChanged: (p) => setState(() => _periodo = p),
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
                  context,
                  'Custos variáveis',
                  fmt(n.custosVariaveisMensal),
                ),
                _linha(
                  context,
                  'Depreciação de equipamentos',
                  fmt(n.depreciacaoMensal),
                ),
                const Divider(height: 20),
                _linha(
                  context,
                  'Total',
                  fmt(n.custosReaisMensais),
                  destaque: true,
                ),
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
                Text(
                  'Percentuais (Configurações → Percentuais de custo)',
                  style: tt.titleMedium,
                ),
                const SizedBox(height: 8),
                _linha(
                  context,
                  'IVA incluído nas vendas',
                  '${n.impostoPercent.toStringAsFixed(1)}%',
                ),
                _linha(
                  context,
                  'CMV (matéria-prima)',
                  '${n.cmvPercent.toStringAsFixed(1)}%',
                ),
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
                'IVA + CMV somam ${(n.impostoPercent + n.cmvPercent).toStringAsFixed(1)}% '
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
                    'Cobre os custos reais + imposto + CMV. Acima disto, cada venda '
                    'ainda paga imposto e CMV; o resto é lucro líquido.',
                    style: tt.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  _linha(
                    context,
                    'Por mês',
                    fmt(n.vendaMinimaMensal!),
                    destaque: true,
                  ),
                  _linha(
                    context,
                    'Por dia (${n.diasUteisMes} dias)',
                    fmt(n.vendaMinimaDiaria!),
                  ),
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
                  Text(
                    '${n.periodo.label}: como vai indo',
                    style: tt.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'De ${n.periodo.intervaloTexto.replaceFirst(' – ', ' a ')} '
                    '(${n.periodo.dias} dias)',
                    style: tt.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  _linha(
                    context,
                    n.periodo.contem(DateTime.now()) &&
                            n.periodo.ate.isAfter(DateTime.now())
                        ? 'Vendido até hoje'
                        : 'Vendido no período',
                    fmt(n.receitaPeriodo),
                  ),
                  _linha(
                    context,
                    n.periodo.tipo == TipoPeriodo.dia
                        ? 'Mínimo para este dia'
                        : 'Mínimo para o período inteiro',
                    fmt(n.vendaMinimaDoPeriodo!),
                  ),
                  if (n.periodoComparado != null) ...[
                    const Divider(height: 20),
                    Text(
                      'Comparação com o período anterior '
                      '(${n.periodoComparado!.intervaloTexto})',
                      style: tt.bodySmall,
                    ),
                    _linha(
                      context,
                      'Vendido nesse período',
                      fmt(n.receitaComparada),
                    ),
                    if (n.variacaoVendidoPercent != null)
                      _linha(
                        context,
                        n.variacaoVendidoPercent! >= 0
                            ? 'Evolução do vendido'
                            : 'Quebra do vendido',
                        '${n.variacaoVendidoPercent! >= 0 ? '+' : ''}'
                        '${n.variacaoVendidoPercent!.toStringAsFixed(1)}%',
                        destaque: true,
                        cor: n.variacaoVendidoPercent! >= 0
                            ? cs.primary
                            : cs.error,
                      )
                    else
                      Text(
                        'Sem vendas nesse período para comparar.',
                        style: tt.bodySmall,
                      ),
                  ],
                  const Divider(height: 20),
                  if (n.faltaParaMinimo! > 0)
                    _linha(
                      context,
                      'Falta vender para bater o mínimo',
                      fmt(n.faltaParaMinimo!),
                      destaque: true,
                      cor: cs.error,
                    )
                  else ...[
                    _linha(
                      context,
                      'Vendido acima do mínimo',
                      fmt(n.vendidoAcimaDoMinimo),
                    ),
                    _linha(
                      context,
                      '− Imposto (${n.impostoPercent.toStringAsFixed(1)}%)',
                      fmt(n.impostoSobreExcedente),
                    ),
                    _linha(
                      context,
                      '− CMV (${n.cmvPercent.toStringAsFixed(1)}%)',
                      fmt(n.cmvSobreExcedente),
                    ),
                    const Divider(height: 20),
                    _linha(
                      context,
                      'Lucro líquido do período',
                      fmt(n.lucroLiquidoPeriodo),
                      destaque: true,
                      cor: cs.primary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Já passaste o mínimo, mas o que vendes a mais ainda '
                      'leva imposto e matéria-prima em cada produto; só o '
                      'resto é lucro.',
                      style: tt.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (n.periodo.dias > 1 &&
              n.periodo.dias <= 31 &&
              n.vendaMinimaDiaria != null) ...[
            const SizedBox(height: 12),
            _diaADia(context, n, fmt),
          ],
        ],
      ],
    );
  }

  /// Dia a dia: o vendido de cada dia contra a venda mínima diária.
  Widget _diaADia(BuildContext context, NumerosMagicos n, MoneyFmt fmt) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final minimo = n.vendaMinimaDiaria!;
    final hoje = DateTime.now();
    final hojeZero = DateTime(hoje.year, hoje.month, hoje.day);
    const sem = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
    final dias = [
      for (var i = 0; i < n.periodo.dias; i++)
        DateTime(
          n.periodo.desde.year,
          n.periodo.desde.month,
          n.periodo.desde.day + i,
        ),
    ].where((d) => !d.isAfter(hojeZero)).toList();
    var bateu = 0;
    for (final d in dias) {
      if ((n.vendasPorDia[d] ?? 0) >= minimo) bateu++;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Dia a dia', style: tt.titleMedium),
            const SizedBox(height: 2),
            Text(
              'Venda mínima por dia: ${fmt(minimo)} · bateste o mínimo em '
              '$bateu de ${dias.length} dia(s).',
              style: tt.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final d in dias.reversed)
              Builder(
                builder: (_) {
                  final v = n.vendasPorDia[d] ?? 0;
                  final ok = v >= minimo;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(
                          ok
                              ? Icons.check_circle_outline
                              : Icons.radio_button_unchecked,
                          size: 18,
                          color: ok ? cs.primary : cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${sem[d.weekday - 1]} '
                            '${d.day.toString().padLeft(2, '0')}/'
                            '${d.month.toString().padLeft(2, '0')}',
                          ),
                        ),
                        Text(
                          fmt(v),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(
                          width: 88,
                          child: Text(
                            ok ? '+${fmt(v - minimo)}' : '−${fmt(minimo - v)}',
                            textAlign: TextAlign.right,
                            style: TextStyle(color: ok ? cs.primary : cs.error),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
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
          Text(
            valor,
            style: style?.copyWith(fontWeight: FontWeight.bold, color: cor),
          ),
        ],
      ),
    );
  }
}
