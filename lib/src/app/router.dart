import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_controller.dart';
import '../core/auth/auth_state.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/onboarding_screen.dart';
import '../features/dashboard/presentation/home_shell.dart';
import '../features/ingredients/presentation/ingredients_screen.dart';

/// Nomes de rota centralizados.
abstract class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const onboarding = '/onboarding';
  static const home = '/';
  static const ingredients = '/ingredientes';
  static const recipes = '/receitas';
  static const techSheets = '/fichas-tecnicas';
  static const settings = '/opcoes';
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
      GoRoute(
        path: Routes.home,
        builder: (_, __) => const HomeShell(),
      ),
      GoRoute(
        path: Routes.ingredients,
        builder: (_, __) => const IngredientsScreen(),
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
