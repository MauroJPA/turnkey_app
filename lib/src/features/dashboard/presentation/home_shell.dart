import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/formatting/money_provider.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/help_actions.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../invoices/application/invoice_providers.dart';
import '../../invoices/domain/fatura.dart';
import '../../schedule/application/schedule_providers.dart';
import '../../schedule/domain/production_plan.dart';
import '../../settings/application/empresa_providers.dart';
import '../../settings/data/empresa_repository.dart';
import '../../shopping/application/shopping_providers.dart';

/// Ecrã inicial: painel com os números que precisam de atenção + atalhos.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const _tudo = <_Section>[
    _Section('Ingredientes', Icons.egg_alt_outlined, 'Preços e fornecedores',
        Routes.ingredients),
    _Section('Receitas', Icons.menu_book_outlined, 'Massas, recheios, coberturas',
        Routes.recipes),
    _Section('Fichas Técnicas', Icons.receipt_long_outlined,
        'Produtos e preço de venda', Routes.techSheets),
    _Section('Faturas', Icons.document_scanner_outlined,
        'Foto da fatura → preços e stock', Routes.invoices),
    _Section('Embalagens', Icons.inventory_2_outlined,
        'Caixas, sacos, adesivos e o seu custo', Routes.embalagens),
    _Section('Formatos de cookie', Icons.cookie_outlined,
        'Tamanhos e recheio por unidade', Routes.cookieFormats),
    _Section('Configurações', Icons.settings_outlined,
        'Empresa, aparência, custos', Routes.settings),
    _Section('Equipa', Icons.group_outlined, 'Utilizadores e permissões',
        Routes.team),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final empresa = ref.watch(currentEmpresaProvider).valueOrNull;
    final userName = ref.watch(currentUserNameProvider);
    final papel = ref.watch(currentPapelProvider);
    final fmt = ref.watch(moneyFormatProvider);

    final logoUrl = empresa == null
        ? ''
        : ref.read(empresaRepositoryProvider).logoUrl(empresa);

    final stock = ref.watch(stockListProvider).valueOrNull;
    final planos = ref.watch(plansListProvider).valueOrNull;
    final compras = ref.watch(shoppingListProvider).valueOrNull;
    final faturas = ref.watch(faturasListProvider).valueOrNull;
    final faturasPorRever = faturas
        ?.where((f) =>
            f.estado == FaturaEstado.nova ||
            f.estado == FaturaEstado.analisada)
        .length;

    final stockBaixo = stock?.where((s) => s.stockBaixo).length;
    final hoje = DateTime.now();
    final proximas = planos
        ?.where((p) =>
            p.estado != EstadoProducao.concluida &&
            p.estado != EstadoProducao.cancelada &&
            !p.data.isBefore(DateTime(hoje.year, hoje.month, hoje.day)))
        .length;
    final porComprar = compras?.where((c) => !c.comprado).toList();
    final valorFalta =
        porComprar?.fold<double>(0, (s, c) => s + c.custoEstimado);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          children: [
            if (logoUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  logoUrl,
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                empresa?.nome ?? 'Turnkey',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          const HelpActions(topic: HelpTopic.dashboard),
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
              const PopupMenuItem(value: 'sair', child: Text('Terminar sessão')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: () => context.go(Routes.miseEnPlace),
              icon: const Icon(Icons.checklist_rtl),
              label: const Text('Mise en place — produzir agora'),
            ),
          ),
          const SizedBox(height: 4),
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
          _StatCard(
            icon: Icons.event_note_outlined,
            titulo: 'Produções por fazer',
            valor: proximas == null ? '—' : '$proximas',
            subtitulo: proximas == null
                ? 'a carregar…'
                : (proximas == 0 ? 'nada agendado' : 'de hoje em diante'),
            onTap: () => context.go(Routes.schedule),
          ),
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
          if ((faturasPorRever ?? 0) > 0)
            _StatCard(
              icon: Icons.rule_folder_outlined,
              titulo: 'Faturas por rever',
              valor: '$faturasPorRever',
              subtitulo: 'confirma os dados lidos pela IA',
              destaque: true,
              onTap: () => context.go(Routes.invoices),
            ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Text('Tudo', style: Theme.of(context).textTheme.titleMedium),
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
                  for (final s in _tudo)
                    Card(
                      child: InkWell(
                        onTap: () => context.go(s.route),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(s.icon, size: 28),
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
                    Text(titulo,
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      subtitulo,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                valor,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
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

class _Section {
  const _Section(this.label, this.icon, this.descricao, this.route);
  final String label;
  final IconData icon;
  final String descricao;
  final String route;
}
