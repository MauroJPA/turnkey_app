import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/env/app_version.dart';
import '../../../core/formatting/money_provider.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/help_actions.dart';
import '../../daily_count/presentation/forno_widgets.dart';
import '../../finance/application/custos_fixos_providers.dart';
import '../../haccp/application/haccp_providers.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../invoices/application/invoice_providers.dart';
import '../../invoices/domain/fatura.dart';
import '../../navigation/application/navigation_providers.dart';
import '../../navigation/domain/pagina_app.dart';
import '../../navigation/presentation/todas_paginas_sheet.dart';
import '../../orders/application/encomendas_providers.dart';
import '../../orders/data/configuracoes_encomendas_repository.dart';
import '../../schedule/application/schedule_providers.dart';
import '../../schedule/domain/production_plan.dart';
import '../../settings/application/empresa_providers.dart';
import '../../settings/data/empresa_repository.dart';
import '../../settings/domain/empresa.dart';
import '../../shopping/application/shopping_providers.dart';

/// Ecrã inicial: painel com os números que precisam de atenção + atalhos.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final empresa = ref.watch(currentEmpresaProvider).valueOrNull;
    final userName = ref.watch(currentUserNameProvider);
    final papel = ref.watch(currentPapelProvider);
    final fmt = ref.watch(moneyFormatProvider);

    final navConfig = ref.watch(navConfigAtualProvider);
    final navPrefs = ref.watch(navPrefsAtualProvider);
    bool acessivel(String chave) => navConfig.acessivel(papel, chave);
    final noRodape = navConfig.rodapePara(papel).map((p) => p.chave).toSet();
    // Grelha: o que a pessoa pode abrir, não está no rodapé e não escondeu.
    final grelha = [
      for (final p in paginasApp)
        if (acessivel(p.chave) &&
            !noRodape.contains(p.chave) &&
            !navPrefs.escondida(p.chave))
          p,
    ];

    final logoUrl = empresa == null
        ? ''
        : ref.read(empresaRepositoryProvider).logoUrl(empresa);

    final stock = ref.watch(stockListProvider).valueOrNull;
    final planos = ref.watch(plansListProvider).valueOrNull;
    final compras = ref.watch(shoppingListProvider).valueOrNull;
    final faturas = ref.watch(faturasListProvider).valueOrNull;
    final faturasPorRever = faturas
        ?.where(
          (f) =>
              f.estado == FaturaEstado.nova ||
              f.estado == FaturaEstado.analisada,
        )
        .length;

    final stockBaixo = stock?.where((s) => s.stockBaixo).length;
    final hoje = DateTime.now();
    final proximas = planos
        ?.where(
          (p) =>
              p.estado != EstadoProducao.concluida &&
              p.estado != EstadoProducao.cancelada &&
              !p.data.isBefore(DateTime(hoje.year, hoje.month, hoje.day)),
        )
        .length;
    final porComprar = compras?.where((c) => !c.comprado).toList();
    final valorFalta = porComprar?.fold<double>(
      0,
      (s, c) => s + c.custoEstimado,
    );

    final custosFixos = ref.watch(custosFixosListProvider(false)).valueOrNull;
    final pagamentosProximos =
        custosFixos
            ?.where((c) => c.diaPagamento != null)
            .map(
              (c) => (custo: c, dias: _diasAtePagamento(c.diaPagamento!, hoje)),
            )
            .where((p) => p.dias <= 7)
            .toList()
          ?..sort((a, b) => a.dias.compareTo(b.dias));

    // só consulta o HACCP a quem tem a página
    final haccpPorFazer = acessivel('haccp')
        ? ref
              .watch(haccpEstadoProvider)
              .valueOrNull
              ?.where((s) => s.precisaAcaoHoje)
              .toList()
        : null;
    final haccpNc = acessivel('haccp')
        ? ref.watch(haccpNaoConformidadesProvider).valueOrNull?.length
        : null;

    final encomendas = ref.watch(encomendasListProvider(false)).valueOrNull;
    final lembreteHoras =
        ref.watch(configuracaoEncomendasProvider).valueOrNull?.lembreteHoras ??
        4;
    final encomendasPorVir =
        encomendas
            ?.where((e) => e.estado.ativa && e.horasAte(hoje) <= lembreteHoras)
            .toList()
          ?..sort((a, b) => a.dataHora.compareTo(b.dataHora));

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: marcaAppBar(context, empresa, logoUrl),
        actions: [
          IconButton(
            tooltip: 'Configurações',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go(Routes.settings),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'sair') {
                ref.read(authControllerProvider.notifier).signOut();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Text('${userName ?? ''} · ${papel.label}'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'sair',
                child: Text('Terminar sessão'),
              ),
              const PopupMenuDivider(),
              // versão da app, discreta (útil para saber se o telemóvel já atualizou)
              PopupMenuItem(
                enabled: false,
                height: 32,
                child: Text(
                  'gc_turnkey · $versaoAppTexto',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const HelpActions(topic: HelpTopic.dashboard),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          if (acessivel('producao'))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                onPressed: () => context.go(Routes.production),
                icon: const Icon(Icons.checklist_rtl),
                label: const Text('Produzir agora'),
              ),
            ),
          const SizedBox(height: 4),
          if (acessivel('inventario'))
            _StatCard(
              icon: Icons.warning_amber_rounded,
              titulo: 'Stock baixo',
              valor: stockBaixo == null ? '—' : '$stockBaixo',
              subtitulo: stockBaixo == null
                  ? 'a carregar…'
                  : (stockBaixo == 0
                        ? 'tudo acima do mínimo'
                        : '${stockBaixo == 1 ? 'item' : 'itens'} abaixo do mínimo'),
              destaque: (stockBaixo ?? 0) > 0,
              onTap: () => context.go(Routes.inventory),
            ),
          if (acessivel('producao'))
            _StatCard(
              icon: Icons.event_note_outlined,
              titulo: 'Produções por fazer',
              valor: proximas == null ? '—' : '$proximas',
              subtitulo: proximas == null
                  ? 'a carregar…'
                  : (proximas == 0 ? 'nada agendado' : 'de hoje em diante'),
              onTap: () => context.go(Routes.schedule),
            ),
          if (acessivel('compras'))
            _StatCard(
              icon: Icons.shopping_cart_outlined,
              titulo: 'A comprar',
              valor: porComprar == null ? '—' : '${porComprar.length}',
              subtitulo: porComprar == null
                  ? 'a carregar…'
                  : (porComprar.isEmpty
                        ? 'nada em falta'
                        : 'estimativa ${fmt(valorFalta ?? 0)}'),
              destaque: (porComprar?.isNotEmpty ?? false),
              onTap: () => context.go(Routes.shopping),
            ),
          if (acessivel('faturas') && (faturasPorRever ?? 0) > 0)
            _StatCard(
              icon: Icons.rule_folder_outlined,
              titulo: 'Faturas por rever',
              valor: '$faturasPorRever',
              subtitulo: 'confirma os dados lidos pela IA',
              destaque: true,
              onTap: () => context.go(Routes.invoices),
            ),
          if (acessivel('financeiro') && (pagamentosProximos?.length ?? 0) > 0)
            _StatCard(
              icon: Icons.event_available_outlined,
              titulo: 'Pagamentos por vir',
              valor: '${pagamentosProximos!.length}',
              subtitulo: pagamentosProximos
                  .take(3)
                  .map(
                    (p) =>
                        '${p.custo.nome} (${p.dias == 0 ? 'hoje' : 'em ${p.dias}d'})',
                  )
                  .join(', '),
              destaque: pagamentosProximos.any((p) => p.dias <= 2),
              onTap: () => context.go(Routes.custosFixos),
            ),
          // o que está no forno (some sozinho quando está vazio)
          if (acessivel('contagem')) const ResumoFornoCard(),
          if (acessivel('haccp') &&
              ((haccpPorFazer?.length ?? 0) > 0 || (haccpNc ?? 0) > 0))
            _StatCard(
              icon: Icons.health_and_safety_outlined,
              titulo: 'HACCP por fazer',
              valor: '${haccpPorFazer?.length ?? 0}',
              subtitulo: [
                if (haccpPorFazer?.isNotEmpty ?? false)
                  haccpPorFazer!.take(3).map((s) => s.controlo.nome).join(', '),
                if ((haccpNc ?? 0) > 0)
                  '$haccpNc não conformidade${haccpNc == 1 ? '' : 's'}',
              ].join(' · '),
              destaque:
                  (haccpNc ?? 0) > 0 ||
                  (haccpPorFazer?.any((s) => s.emAtraso) ?? false),
              onTap: () => context.go(Routes.haccp),
            ),
          if (acessivel('encomendas') && (encomendasPorVir?.length ?? 0) > 0)
            _StatCard(
              icon: Icons.event_note_outlined,
              titulo: 'Encomendas por vir',
              valor: '${encomendasPorVir!.length}',
              subtitulo: encomendasPorVir
                  .take(3)
                  .map((e) => e.clienteNome)
                  .join(', '),
              destaque: encomendasPorVir.any((e) => e.horasAte(hoje) <= 1),
              onTap: () => context.go(Routes.encomendas),
            ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 0, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Tudo',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => showTodasPaginasSheet(context),
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Todas as páginas'),
                ),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, c) {
              final cols = (c.maxWidth ~/ 200).clamp(2, 4);
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: cols,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.35,
                children: [
                  for (final s in grelha)
                    Card(
                      key: ValueKey('grelha-${s.chave}'),
                      color: navPrefs.cor(s.chave)?.withValues(alpha: 0.16),
                      child: InkWell(
                        onTap: () => context.go(s.rota),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                s.icon,
                                size: 28,
                                color: navPrefs.cor(s.chave),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                s.label,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                s.descricao,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.titulo,
    required this.valor,
    required this.subtitulo,
    required this.onTap,
    this.destaque = false,
  });

  final IconData icon;
  final String titulo;
  final String valor;
  final String subtitulo;
  final VoidCallback onTap;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: destaque ? cs.errorContainer : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                icon,
                size: 32,
                color: destaque ? cs.onErrorContainer : cs.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      subtitulo,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                valor,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// Logótipo e/ou nome da marca na barra superior, com a posição, tamanho e
/// visibilidade escolhidos em Configurações → Aparência. Público para a
/// pré-visualização em tempo real no ecrã de Configurações usar exatamente
/// o mesmo desenho da barra real.
Widget marcaAppBar(BuildContext context, Empresa? empresa, String logoUrl) {
  final mostrarLogo = (empresa?.logoVisivel ?? true) && logoUrl.isNotEmpty;
  final mostrarNome = empresa?.nomeVisivel ?? true;
  final tamanhoLogo = empresa?.logoTamanho ?? 28;

  final logo = !mostrarLogo
      ? null
      : ClipRRect(
          borderRadius: BorderRadius.circular(6),
          // Logótipos não são todos quadrados (ex.: uma marca larga tipo
          // wordmark) — em vez de forçar um quadrado e cortar as pontas
          // (BoxFit.cover), mede-se pela altura e mantém-se a proporção
          // (BoxFit.contain), com um teto de largura para não estourar a
          // barra com um logótipo muito largo.
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: tamanhoLogo * 4),
            child: SizedBox(
              height: tamanhoLogo,
              child: Image.network(
                logoUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        );
  final texto = !mostrarNome
      ? null
      : Text(
          empresa?.nome ?? 'gc_turnkey',
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: empresa?.nomeTamanho ?? 18,
          ),
        );
  if (logo == null && texto == null) return const SizedBox.shrink();

  final logoAlinh = empresa?.logoAlinhamento ?? Alinhamento.esquerda;
  final nomeAlinh = empresa?.nomeAlinhamento ?? Alinhamento.esquerda;

  // Mesma posição (ou só um dos dois visível) — ficam juntos numa linha.
  if (logo == null || texto == null || logoAlinh == nomeAlinh) {
    final conteudo = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (logo != null) logo,
        if (logo != null && texto != null) const SizedBox(width: 8),
        if (texto != null) Flexible(child: texto),
      ],
    );
    return SizedBox(
      width: double.infinity,
      child: Align(
        alignment: _alignFor(logo != null ? logoAlinh : nomeAlinh),
        child: conteudo,
      ),
    );
  }

  // Posições diferentes — cada um fica na sua zona da barra.
  return SizedBox(
    width: double.infinity,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Align(alignment: _alignFor(logoAlinh), child: logo),
        Align(alignment: _alignFor(nomeAlinh), child: texto),
      ],
    ),
  );
}

/// Dias até ao próximo dia [diaPagamento] deste mês (ou do mês seguinte, se
/// já tiver passado neste). `0` = hoje.
int _diasAtePagamento(int diaPagamento, DateTime hoje) {
  final hojeSoData = DateTime(hoje.year, hoje.month, hoje.day);
  var proximo = DateTime(hoje.year, hoje.month, diaPagamento);
  if (proximo.isBefore(hojeSoData)) {
    proximo = DateTime(hoje.year, hoje.month + 1, diaPagamento);
  }
  return proximo.difference(hojeSoData).inDays;
}

Alignment _alignFor(Alinhamento a) => switch (a) {
  Alinhamento.esquerda => Alignment.centerLeft,
  Alinhamento.centro => Alignment.center,
  Alinhamento.direita => Alignment.centerRight,
};
