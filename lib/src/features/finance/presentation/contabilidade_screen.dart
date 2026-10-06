import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/help_actions.dart';
import '../../../core/widgets/hub_segmentos.dart';
import '../../invoices/presentation/contabilidade_sheet.dart';
import '../domain/periodo.dart';
import 'custos_fixos_screen.dart';
import 'dre_screen.dart';
import 'equipamentos_screen.dart';
import 'iva_card.dart';
import 'numeros_magicos_screen.dart';
import 'painel_financeiro_screen.dart';
import 'relatorio_geral_sheet.dart';
import 'rentabilidade_view.dart';
import 'seletor_periodo.dart';
import 'tabela_revendedor_view.dart';

/// As secções da Contabilidade.
enum SecaoContabilidade {
  resumo('Resumo', Icons.insights_outlined, Routes.painelFinanceiro),
  dre('DRE', Icons.description_outlined, Routes.dre),
  custos('Custos fixos', Icons.request_quote_outlined, Routes.custosFixos),
  equipamentos('Equipamentos', Icons.kitchen_outlined, Routes.equipamentos),
  numeros('Números mágicos', Icons.calculate_outlined, Routes.numerosMagicos),
  rentabilidade(
    'Rentabilidade',
    Icons.leaderboard_outlined,
    Routes.rentabilidade,
  ),
  revendedores(
    'Revendedores',
    Icons.price_change_outlined,
    Routes.tabelaRevendedores,
  ),
  relatorios('Relatórios e IVA', Icons.summarize_outlined, Routes.relatorios);

  const SecaoContabilidade(this.label, this.icon, this.rota);
  final String label;
  final IconData icon;
  final String rota;

  HelpTopic get ajuda => switch (this) {
    SecaoContabilidade.resumo => HelpTopic.painelFinanceiro,
    SecaoContabilidade.dre => HelpTopic.dre,
    SecaoContabilidade.custos => HelpTopic.custosFixos,
    SecaoContabilidade.equipamentos => HelpTopic.equipamentos,
    SecaoContabilidade.numeros => HelpTopic.numerosMagicos,
    SecaoContabilidade.rentabilidade => HelpTopic.rentabilidade,
    SecaoContabilidade.revendedores => HelpTopic.tabelaRevendedores,
    SecaoContabilidade.relatorios => HelpTopic.contabilidade,
  };
}

/// Contabilidade: os números da empresa numa só página — o resumo (entradas,
/// saídas, lucro), a DRE, os custos fixos, os equipamentos, os números
/// mágicos e os relatórios (IVA, relatório geral, exportação para a
/// contabilista).
class ContabilidadeScreen extends ConsumerWidget {
  const ContabilidadeScreen({super.key, required this.secao});

  final SecaoContabilidade secao;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
        title: const Text('Contabilidade'),
        actions: [HelpActions(topic: secao.ajuda)],
      ),
      body: Column(
        children: [
          HubSegmentos<SecaoContabilidade>(
            principais: const [
              SecaoContabilidade.resumo,
              SecaoContabilidade.custos,
              SecaoContabilidade.relatorios,
            ],
            extras: const [
              SecaoContabilidade.dre,
              SecaoContabilidade.equipamentos,
              SecaoContabilidade.numeros,
              SecaoContabilidade.rentabilidade,
              SecaoContabilidade.revendedores,
            ],
            atual: secao,
            rotulo: (s) => s.label,
            icone: (s) => s.icon,
            aoEscolher: (s) => context.go(s.rota),
          ),
          Expanded(
            child: switch (secao) {
              SecaoContabilidade.resumo => const PainelFinanceiroScreen(
                key: ValueKey('cont-resumo'),
                embedded: true,
              ),
              SecaoContabilidade.dre => const DreScreen(
                key: ValueKey('cont-dre'),
                embedded: true,
              ),
              SecaoContabilidade.custos => const CustosFixosScreen(
                key: ValueKey('cont-custos'),
                embedded: true,
              ),
              SecaoContabilidade.equipamentos => const EquipamentosScreen(
                key: ValueKey('cont-equip'),
                embedded: true,
              ),
              SecaoContabilidade.numeros => const NumerosMagicosScreen(
                key: ValueKey('cont-numeros'),
                embedded: true,
              ),
              SecaoContabilidade.rentabilidade => const RentabilidadeView(
                key: ValueKey('cont-rentabilidade'),
              ),
              SecaoContabilidade.revendedores => const TabelaRevendedorView(
                key: ValueKey('cont-revendedores'),
              ),
              SecaoContabilidade.relatorios => const _Relatorios(
                key: ValueKey('cont-relatorios'),
              ),
            },
          ),
        ],
      ),
    );
  }
}

/// IVA do período e os relatórios para exportar ou entregar à contabilista.
class _Relatorios extends ConsumerStatefulWidget {
  const _Relatorios({super.key});

  @override
  ConsumerState<_Relatorios> createState() => _RelatoriosState();
}

class _RelatoriosState extends ConsumerState<_Relatorios> {
  late Periodo _periodo = Periodo.mesDe(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final podeConfig = ref.watch(currentPapelProvider).canEditConfig;
    final tt = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        SeletorPeriodo(
          periodo: _periodo,
          onChanged: (p) => setState(() => _periodo = p),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: IvaCard(periodo: _periodo),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Text('Relatórios', style: tt.titleMedium),
        ),
        if (podeConfig)
          ListTile(
            leading: const Icon(Icons.summarize_outlined),
            title: const Text('Relatório geral (Excel / CSV)'),
            subtitle: const Text(
              'Vendas, produção, custos, despesas, plataformas, pessoal…',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                showRelatorioGeralSheet(context, periodoDoPainel: _periodo),
          ),
        ListTile(
          leading: const Icon(Icons.receipt_long_outlined),
          title: const Text('Faturas para a contabilista'),
          subtitle: const Text(
            'Descarrega ou envia as faturas de compra de um mês',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showContabilidadeSheet(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.shopping_basket_outlined),
          title: const Text('O que comprei'),
          subtitle: const Text(
            'Compras do período por dia, fornecedor ou produto',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(Routes.comprasRelatorio),
        ),
        ListTile(
          leading: const Icon(Icons.bar_chart_outlined),
          title: const Text('Análise de vendas'),
          subtitle: const Text('O que mais vende, por produto e por canal'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(Routes.analiseVendas),
        ),
        ListTile(
          leading: const Icon(Icons.fact_check_outlined),
          title: const Text('Relatórios HACCP'),
          subtitle: const Text(
            'Registos de segurança alimentar, para imprimir',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(Routes.haccp),
        ),
      ],
    );
  }
}
