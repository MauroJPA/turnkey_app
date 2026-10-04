import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_controller.dart';
import '../core/auth/auth_state.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/onboarding_screen.dart';
import '../features/auth/presentation/pending_approval_screen.dart';
import '../features/cookie_formats/presentation/cookie_formats_screen.dart';
import '../features/daily_count/presentation/contagem_relatorios_screen.dart';
import '../features/daily_count/presentation/contagem_screen.dart';
import '../features/dashboard/presentation/home_shell.dart';
import '../features/dashboard/presentation/main_shell.dart';
import '../features/finance/presentation/analise_vendas_screen.dart';
import '../features/finance/presentation/custos_fixos_screen.dart';
import '../features/finance/presentation/dre_screen.dart';
import '../features/finance/presentation/equipamentos_screen.dart';
import '../features/finance/presentation/numeros_magicos_screen.dart';
import '../features/finance/presentation/painel_financeiro_screen.dart';
import '../features/haccp/presentation/haccp_screen.dart';
import '../features/inventory/presentation/inventario_screen.dart';
import '../features/invoices/presentation/invoice_review_screen.dart';
import '../features/invoices/presentation/invoices_screen.dart';
import '../features/mise_en_place/presentation/mep_screen.dart';
import '../features/navigation/presentation/navegacao_screen.dart';
import '../features/orders/presentation/encomenda_detail_screen.dart';
import '../features/orders/presentation/encomendas_screen.dart';
import '../features/production/presentation/cart_review_screen.dart';
import '../features/production/presentation/production_screen.dart';
import '../features/products/presentation/produto_detail_screen.dart';
import '../features/quiosque/presentation/colaboradores_screen.dart';
import '../features/quiosque/presentation/quiosque_screen.dart';
import '../features/recipe_categories/presentation/recipe_categories_screen.dart';
import '../features/recipes/presentation/recipe_detail_screen.dart';
import '../features/recipes/presentation/recipes_screen.dart';
import '../features/sales/presentation/produtos_nao_identificados_screen.dart';
import '../features/sales/presentation/sales_screen.dart';
import '../features/sales/presentation/venda_detail_screen.dart';
import '../features/schedule/presentation/plan_detail_screen.dart';
import '../features/schedule/presentation/schedule_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/settings/presentation/team_screen.dart';
import '../features/shopping/presentation/compras_relatorio_screen.dart';
import '../features/shopping/presentation/shopping_screen.dart';
import '../features/tech_sheets/presentation/tech_sheet_detail_screen.dart';
import '../features/tech_sheets/presentation/tech_sheets_screen.dart';
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
      GoRoute(
        path: Routes.splash,
        builder: (_, __) => const _SplashScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (_, __) => const LoginScreen(),
      ),
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
          GoRoute(
            path: Routes.home,
            builder: (_, __) => const HomeShell(),
          ),
          GoRoute(
            path: Routes.production,
            builder: (_, __) => const ProductionScreen(),
            routes: [
              GoRoute(
                path: 'agendar',
                builder: (_, __) => const CartReviewScreen(),
              ),
            ],
          ),
          GoRoute(
            path: Routes.miseEnPlace,
            builder: (_, state) => MiseEnPlaceScreen(
              receitaId: state.uri.queryParameters['receita'],
            ),
          ),
          GoRoute(
            path: Routes.schedule,
            builder: (_, __) => const ScheduleScreen(),
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
            ],
          ),
          GoRoute(
            path: Routes.invoices,
            builder: (_, __) => const InvoicesScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => InvoiceReviewScreen(
                  faturaId: state.pathParameters['id']!,
                ),
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
                builder: (_, state) => VendaDetailScreen(
                  vendaId: state.pathParameters['id']!,
                ),
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
          GoRoute(
            path: Routes.haccp,
            builder: (_, __) => const HaccpScreen(),
          ),
          GoRoute(
            path: Routes.colaboradores,
            builder: (_, __) => const ColaboradoresScreen(),
          ),
          GoRoute(
            path: Routes.painelFinanceiro,
            builder: (_, __) => const PainelFinanceiroScreen(),
          ),
          GoRoute(
            path: Routes.dre,
            builder: (_, __) => const DreScreen(),
          ),
          GoRoute(
            path: Routes.custosFixos,
            builder: (_, __) => const CustosFixosScreen(),
          ),
          GoRoute(
            path: Routes.equipamentos,
            builder: (_, __) => const EquipamentosScreen(),
          ),
          GoRoute(
            path: Routes.numerosMagicos,
            builder: (_, __) => const NumerosMagicosScreen(),
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
                builder: (_, state) => RecipeDetailScreen(
                  recipeId: state.pathParameters['id']!,
                ),
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
                builder: (_, state) => TechSheetDetailScreen(
                  fichaId: state.pathParameters['id']!,
                ),
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
              GoRoute(
                path: 'equipa',
                builder: (_, __) => const TeamScreen(),
              ),
              GoRoute(
                path: 'formatos',
                builder: (_, __) => const CookieFormatsScreen(),
              ),
              GoRoute(
                path: 'categorias-receita',
                builder: (_, __) => const RecipeCategoriesScreen(),
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
