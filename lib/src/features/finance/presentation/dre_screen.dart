import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/money_provider.dart';
import '../../../core/help/help_content.dart';
import '../../../core/printing/print_html.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/help_actions.dart';
import '../../settings/application/empresa_providers.dart';
import '../application/resumo_financeiro_providers.dart';
import '../domain/periodo.dart';
import '../domain/resumo_financeiro.dart';

/// DRE (Demonstração de Resultados do Exercício) simplificada — a mesma
/// [ResumoFinanceiro] do painel financeiro, apresentada no formato de
/// relatório clássico (receita → custo → lucro bruto → despesas → resultado)
/// e pronta a imprimir.
class DreScreen extends ConsumerStatefulWidget {
  const DreScreen({super.key});

  @override
  ConsumerState<DreScreen> createState() => _DreScreenState();
}

class _DreScreenState extends ConsumerState<DreScreen> {
  late Periodo _periodo = Periodo.semanaAtual();

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(resumoFinanceiroProvider(_periodo));
    final fmt = ref.watch(moneyFormatProvider);
    final nomeEmpresa = ref.watch(currentEmpresaProvider).valueOrNull?.nome ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('DRE'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Imprimir',
            onPressed: async.valueOrNull == null
                ? null
                : () => abrirImpressao(
                      'DRE — ${_periodo.label}',
                      _dreHtml(async.valueOrNull!, nomeEmpresa, fmt),
                    ),
          ),
          const HelpActions(topic: HelpTopic.dre),
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
            child: AsyncValueView<ResumoFinanceiro>(
              value: async,
              onRetry: () => ref.invalidate(resumoFinanceiroProvider(_periodo)),
              data: (r) => _corpo(context, r, fmt),
            ),
          ),
        ],
      ),
    );
  }

  Widget _corpo(BuildContext context, ResumoFinanceiro r, MoneyFmt fmt) {
    final tt = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (r.numVendas == 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Sem vendas neste período.',
              textAlign: TextAlign.center,
              style: tt.bodyMedium,
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _linha(context, 'Receita bruta de vendas', fmt(r.receita),
                    destaque: true),
                _linha(context, '(-) Custo dos produtos vendidos',
                    fmt(r.custoProdutos)),
                const Divider(height: 20),
                _linha(context, '(=) Lucro bruto', fmt(r.lucroBruto),
                    destaque: true),
                const SizedBox(height: 12),
                Text('(-) Despesas operacionais', style: tt.bodySmall),
                _linha(context, 'Custos fixos', fmt(r.custosFixos),
                    indent: true),
                _linha(context, 'Custos variáveis', fmt(r.custosVariaveis),
                    indent: true),
                _linha(context, 'Total despesas operacionais',
                    fmt(r.despesasOperacionais)),
                const Divider(height: 20),
                _linha(context, '(=) Resultado líquido do período',
                    fmt(r.lucroLiquido), destaque: true),
                _linha(context, 'Margem líquida',
                    '${r.margemLiquidaPercent.toStringAsFixed(1)}%'),
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
      ],
    );
  }

  Widget _linha(BuildContext context, String label, String valor,
      {bool destaque = false, bool indent = false}) {
    final style = destaque
        ? Theme.of(context).textTheme.titleSmall
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: EdgeInsets.only(left: indent ? 16 : 0, top: 4, bottom: 4),
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

String _esc(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

/// Corpo HTML da DRE para [abrirImpressao] (`core/printing/print_html.dart`).
/// Visual provisório, no mesmo estilo simples da declaração nutricional.
String _dreHtml(ResumoFinanceiro r, String nomeEmpresa, MoneyFmt fmt) {
  String linha(String rotulo, String valor, {bool indent = false}) =>
      '<tr><td class="${indent ? 'indent' : ''}">${_esc(rotulo)}</td>'
      '<td class="valor">${_esc(valor)}</td></tr>';

  return '''
<h1>DRE — ${_esc(r.periodo.label)}</h1>
<p class="sub">${_esc(nomeEmpresa)} · ${_esc(_ymd(r.periodo.desde))} a ${_esc(_ymd(r.periodo.ate))}</p>
<table>
${linha('Receita bruta de vendas', fmt(r.receita))}
${linha('(-) Custo dos produtos vendidos', fmt(r.custoProdutos))}
${linha('(=) Lucro bruto', fmt(r.lucroBruto))}
${linha('Custos fixos', fmt(r.custosFixos), indent: true)}
${linha('Custos variáveis', fmt(r.custosVariaveis), indent: true)}
${linha('Total despesas operacionais', fmt(r.despesasOperacionais))}
${linha('(=) Resultado líquido do período', fmt(r.lucroLiquido))}
${linha('Margem líquida', '${r.margemLiquidaPercent.toStringAsFixed(1)}%')}
</table>
${r.numLinhasSemFicha > 0 ? '<p class="aviso">(!) ${r.numLinhasSemFicha} linha(s) de venda sem produto identificado — o custo dessas linhas não entra no cálculo (fica sobrestimado).</p>' : ''}
''';
}

String _ymd(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
