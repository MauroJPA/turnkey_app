import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_controller.dart';
import '../core/auth/auth_state.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/onboarding_screen.dart';
import '../features/auth/presentation/pending_approval_screen.dart';
import '../features/daily_count/presentation/contagem_relatorios_screen.dart';
import '../features/daily_count/presentation/contagem_screen.dart';
import '../features/dashboard/presentation/home_shell.dart';
import '../features/dashboard/presentation/main_shell.dart';
import '../features/data_health/presentation/saude_dados_screen.dart';
import '../features/finance/presentation/analise_vendas_screen.dart';
import '../features/finance/presentation/contabilidade_screen.dart';
import '../features/haccp/presentation/haccp_screen.dart';
import '../features/inventory/presentation/inventario_screen.dart';
import '../features/invoices/presentation/invoice_review_screen.dart';
import '../features/invoices/presentation/invoices_screen.dart';
import '../features/navigation/presentation/navegacao_screen.dart';
import '../features/orders/presentation/encomenda_detail_screen.dart';
import '../features/orders/presentation/encomendas_screen.dart';
import '../features/people/presentation/pessoas_screen.dart';
import '../features/production/presentation/cart_review_screen.dart';
import '../features/production/presentation/producao_screen.dart';
import '../features/products/presentation/produto_detail_screen.dart';
import '../features/quiosque/presentation/colaboradores_screen.dart';
import '../features/quiosque/presentation/quiosque_screen.dart';
import '../features/recipes/presentation/recipe_detail_screen.dart';
import '../features/recipes/presentation/recipes_screen.dart';
import '../features/sales/presentation/produtos_nao_identificados_screen.dart';
import '../features/sales/presentation/sales_screen.dart';
import '../features/sales/presentation/venda_detail_screen.dart';
import '../features/schedule/presentation/plan_detail_screen.dart';
import '../features/settings/presentation/aprovacoes_screen.dart';
import '../features/settings/presentation/avisos_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/settings/presentation/team_screen.dart';
import '../features/shopping/presentation/compras_relatorio_screen.dart';
import '../features/shopping/presentation/shopping_screen.dart';
import '../features/tech_sheets/presentation/tech_sheet_detail_screen.dart';
import '../features/tech_sheets/presentation/tech_sheets_screen.dart';
import '../features/traceability/presentation/lote_detail_screen.dart';
import 'routes.dart';

export 'routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;

      switch (auth) {
        case AuthUnknown():
          return loc == Routes.splash ? null : Routes.splash;
        case AuthSignedOut():
          return loc == Routes.login ? null : Routes.login;
        case AuthPendingApproval():
          return loc == Routes.pendente ? null : Routes.pendente;
        case AuthNeedsOnboarding():
          return loc == Routes.onboarding ? null : Routes.onboarding;
        case AuthSignedIn():
          const gates = {
            Routes.splash,
            Routes.login,
            Routes.onboarding,
            Routes.pendente,
          };
          return gates.contains(loc) ? Routes.home : null;
      }
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, __) => const _SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: Routes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: Routes.pendente,
        builder: (_, __) => const PendingApprovalScreen(),
      ),
      // Quiosque de tarefas: ecrã inteiro, sem rodapé, para o telemóvel que
      // fica na loja/fábrica com os cartões NFC dos colaboradores.
      GoRoute(
        path: Routes.quiosque,
        builder: (_, __) => const QuiosqueScreen(),
      ),
      // Todas as secções autenticadas — sempre com a barra de navegação
      // inferior (rodapé) para acesso rápido a qualquer página.
      ShellRoute(
        builder: (_, __, child) => MainShell(child: child),
        routes: [
          GoRoute(path: Routes.home, builder: (_, __) => const HomeShell()),
          // Produção: Produzir (+ mise en place) e Agenda numa só página
          GoRoute(
            path: Routes.production,
            builder: (_, state) => ProducaoScreen(
              secao: SecaoProducao.produzir,
              receitaId: state.uri.queryParameters['receita'],
              kgInicial: double.tryParse(state.uri.queryParameters['kg'] ?? ''),
            ),
            routes: [
              GoRoute(
                path: 'agendar',
                builder: (_, __) => const CartReviewScreen(),
              ),
              GoRoute(
                path: 'previsao',
                builder: (_, __) =>
                    const ProducaoScreen(secao: SecaoProducao.previsao),
              ),
              GoRoute(
                path: 'lotes',
                builder: (_, __) =>
                    const ProducaoScreen(secao: SecaoProducao.lotes),
              ),
            ],
          ),
          // a página de um lote (é o que o QR da etiqueta abre)
          GoRoute(
            path: '${Routes.loteBase}/:codigo',
            builder: (_, state) =>
                LoteDetailScreen(codigo: state.pathParameters['codigo']!),
          ),
          // a antiga página "Mise en place" é agora o Produzir
          GoRoute(
            path: Routes.miseEnPlace,
            redirect: (_, state) =>
                '${Routes.production}${state.uri.hasQuery ? '?${state.uri.query}' : ''}',
          ),
          GoRoute(
            path: Routes.schedule,
            builder: (_, __) =>
                const ProducaoScreen(secao: SecaoProducao.agenda),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    PlanDetailScreen(planId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: Routes.shopping,
            builder: (_, __) => const ShoppingScreen(),
            routes: [
              GoRoute(
                path: 'relatorio',
                builder: (_, __) => const ComprasRelatorioScreen(),
              ),
            ],
          ),
          // Inventário: uma página com secções (ingredientes, limpeza e
          // insumos, material da loja, embalagens)
          GoRoute(
            path: Routes.inventory,
            builder: (_, __) =>
                const InventarioScreen(secao: SecaoInventario.ingredientes),
            routes: [
              GoRoute(
                path: 'limpeza',
                builder: (_, __) =>
                    const InventarioScreen(secao: SecaoInventario.limpeza),
              ),
              GoRoute(
                path: 'material',
                builder: (_, __) =>
                    const InventarioScreen(secao: SecaoInventario.material),
              ),
              GoRoute(
                path: 'embalagens',
                builder: (_, __) =>
                    const InventarioScreen(secao: SecaoInventario.embalagens),
              ),
              GoRoute(
                path: 'precos',
                builder: (_, __) =>
                    const InventarioScreen(secao: SecaoInventario.precos),
              ),
            ],
          ),
          GoRoute(
            path: Routes.invoices,
            builder: (_, __) => const InvoicesScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    InvoiceReviewScreen(faturaId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: Routes.sales,
            builder: (_, __) => const SalesScreen(),
            routes: [
              GoRoute(
                path: 'analise',
                builder: (_, __) => const AnaliseVendasScreen(),
              ),
              GoRoute(
                path: 'nao-identificados',
                builder: (_, __) => const ProdutosNaoIdentificadosScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    VendaDetailScreen(vendaId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: Routes.encomendas,
            builder: (_, __) => const EncomendasScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => EncomendaDetailScreen(
                  encomendaId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: Routes.contagem,
            builder: (_, __) => const ContagemScreen(),
            routes: [
              GoRoute(
                path: 'relatorios',
                builder: (_, __) => const ContagemRelatoriosScreen(),
              ),
            ],
          ),
          GoRoute(path: Routes.haccp, builder: (_, __) => const HaccpScreen()),
          GoRoute(
            path: Routes.colaboradores,
            builder: (_, __) => const ColaboradoresScreen(),
          ),
          // Pessoas: ponto (e, a seguir, férias e notas) numa página
          GoRoute(
            path: Routes.pessoas,
            redirect: (_, state) =>
                state.uri.path == Routes.pessoas ? Routes.pessoasPonto : null,
          ),
          for (final s in SecaoPessoas.values)
            GoRoute(
              path: s.rota,
              pageBuilder: (_, __) => NoTransitionPage(
                key: const ValueKey('pessoas'),
                child: PessoasScreen(secao: s),
              ),
            ),
          // Contabilidade: uma página, várias secções (cada uma com o seu endereço)
          for (final s in SecaoContabilidade.values)
            GoRoute(
              path: s.rota,
              pageBuilder: (_, __) => NoTransitionPage(
                key: const ValueKey('contabilidade'),
                child: ContabilidadeScreen(secao: s),
              ),
            ),
          // endereços antigos (favoritos, links): vão para a secção certa
          GoRoute(
            path: Routes.embalagens,
            redirect: (_, __) => Routes.inventoryEmbalagens,
          ),
          GoRoute(
            path: Routes.consumiveis,
            redirect: (_, __) => Routes.inventoryLimpeza,
          ),
          GoRoute(
            path: Routes.ingredients,
            redirect: (_, __) => Routes.inventory,
          ),
          GoRoute(
            path: Routes.recipes,
            builder: (_, __) => const RecipesScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    RecipeDetailScreen(recipeId: state.pathParameters['id']!),
              ),
            ],
          ),
          // a antiga página "Produtos" passou para dentro da ficha técnica
          GoRoute(
            path: Routes.produtos,
            redirect: (_, __) => Routes.techSheets,
            routes: [
              GoRoute(
                path: ':id',
                redirect: (_, state) =>
                    Routes.fichaInformacao(state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: Routes.techSheets,
            builder: (_, __) => const TechSheetsScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    TechSheetDetailScreen(fichaId: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'informacao',
                    builder: (_, state) => ProdutoDetailScreen(
                      fichaId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: Routes.settings,
            builder: (_, __) => const SettingsScreen(),
            routes: [
              GoRoute(path: 'equipa', builder: (_, __) => const TeamScreen()),
              GoRoute(
                path: 'dados',
                builder: (_, __) => const SaudeDadosScreen(),
              ),
              GoRoute(
                path: 'aprovacoes',
                builder: (_, __) => const AprovacoesScreen(),
              ),
              GoRoute(path: 'avisos', builder: (_, __) => const AvisosScreen()),
              // formatos e categorias já não têm página: gerem-se na ficha/receita
              GoRoute(path: 'formatos', redirect: (_, __) => Routes.techSheets),
              GoRoute(
                path: 'categorias-receita',
                redirect: (_, __) => Routes.recipes,
              ),
              GoRoute(
                path: 'navegacao',
                builder: (_, __) => const NavegacaoScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Rota não encontrada: ${state.uri}')),
    ),
  );
});

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
