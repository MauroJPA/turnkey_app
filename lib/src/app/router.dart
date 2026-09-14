import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_controller.dart';
import '../core/auth/auth_state.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/onboarding_screen.dart';
import '../features/cookie_formats/presentation/cookie_formats_screen.dart';
import '../features/dashboard/presentation/home_shell.dart';
import '../features/dashboard/presentation/main_shell.dart';
import '../features/finance/presentation/analise_vendas_screen.dart';
import '../features/finance/presentation/custos_fixos_screen.dart';
import '../features/finance/presentation/dre_screen.dart';
import '../features/finance/presentation/equipamentos_screen.dart';
import '../features/finance/presentation/numeros_magicos_screen.dart';
import '../features/finance/presentation/painel_financeiro_screen.dart';
import '../features/ingredients/presentation/ingredients_screen.dart';
import '../features/inventory/presentation/inventory_screen.dart';
import '../features/invoices/presentation/invoice_review_screen.dart';
import '../features/invoices/presentation/invoices_screen.dart';
import '../features/mise_en_place/presentation/mep_screen.dart';
import '../features/packaging/presentation/embalagens_screen.dart';
import '../features/production/presentation/cart_review_screen.dart';
import '../features/production/presentation/production_screen.dart';
import '../features/recipes/presentation/recipe_detail_screen.dart';
import '../features/recipes/presentation/recipes_screen.dart';
import '../features/sales/presentation/sales_screen.dart';
import '../features/sales/presentation/venda_detail_screen.dart';
import '../features/schedule/presentation/plan_detail_screen.dart';
import '../features/schedule/presentation/schedule_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/settings/presentation/team_screen.dart';
import '../features/shopping/presentation/shopping_screen.dart';
import '../features/tech_sheets/presentation/tech_sheet_detail_screen.dart';
import '../features/tech_sheets/presentation/tech_sheets_screen.dart';

/// Nomes de rota centralizados.
abstract class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const onboarding = '/onboarding';
  static const home = '/';
  static const ingredients = '/ingredientes';
  static const recipes = '/receitas';
  static const techSheets = '/fichas-tecnicas';
  static const production = '/produzir';
  static const miseEnPlace = '/mise-en-place';
  static const schedule = '/agenda';
  static const shopping = '/compras';
  static const inventory = '/inventario';
  static const invoices = '/faturas';
  static const sales = '/vendas';
  static const analiseVendas = '/vendas/analise';
  static const painelFinanceiro = '/financeiro';
  static const dre = '/financeiro/dre';
  static const custosFixos = '/financeiro/custos-fixos';
  static const equipamentos = '/financeiro/equipamentos';
  static const numerosMagicos = '/financeiro/numeros-magicos';
  static const embalagens = '/embalagens';
  static const settings = '/opcoes';
  static const team = '/opcoes/equipa';
  static const cookieFormats = '/opcoes/formatos';
}

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
        case AuthNeedsOnboarding():
          return loc == Routes.onboarding ? null : Routes.onboarding;
        case AuthSignedIn():
          const gates = {Routes.splash, Routes.login, Routes.onboarding};
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
          ),
          GoRoute(
            path: Routes.inventory,
            builder: (_, __) => const InventoryScreen(),
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
                path: ':id',
                builder: (_, state) => VendaDetailScreen(
                  vendaId: state.pathParameters['id']!,
                ),
              ),
            ],
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
          GoRoute(
            path: Routes.embalagens,
            builder: (_, __) => const EmbalagensScreen(),
          ),
          GoRoute(
            path: Routes.ingredients,
            builder: (_, __) => const IngredientsScreen(),
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
          GoRoute(
            path: Routes.techSheets,
            builder: (_, __) => const TechSheetsScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => TechSheetDetailScreen(
                  fichaId: state.pathParameters['id']!,
                ),
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
