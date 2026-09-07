import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/dashboard/presentation/home_shell.dart';

/// Nomes de rota centralizados.
abstract class Routes {
  static const login = '/login';
  static const home = '/';
  static const ingredients = '/ingredientes';
  static const recipes = '/receitas';
  static const techSheets = '/fichas-tecnicas';
  static const settings = '/opcoes';
}

/// Router da app. O redirect por estado de autenticação entra no M1.
final router = GoRouter(
  initialLocation: Routes.home,
  routes: [
    GoRoute(
      path: Routes.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: Routes.home,
      builder: (context, state) => const HomeShell(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(child: Text('Rota não encontrada: ${state.uri}')),
  ),
);
