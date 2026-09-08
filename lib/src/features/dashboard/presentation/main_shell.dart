import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';

/// Casca das secções principais: mostra a barra de navegação inferior fixa.
/// Cada secção mantém o seu próprio `AppBar`.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  static const _abas = <({String rota, IconData icon, String label})>[
    (rota: Routes.home, icon: Icons.home_outlined, label: 'Início'),
    (
      rota: Routes.miseEnPlace,
      icon: Icons.checklist_rtl,
      label: 'Mise'
    ),
    (rota: Routes.production, icon: Icons.blender_outlined, label: 'Produzir'),
    (rota: Routes.schedule, icon: Icons.event_note_outlined, label: 'Agenda'),
    (
      rota: Routes.shopping,
      icon: Icons.shopping_cart_outlined,
      label: 'Compras'
    ),
    (
      rota: Routes.inventory,
      icon: Icons.warehouse_outlined,
      label: 'Inventário'
    ),
  ];

  int _indice(String location) {
    // corresponde à aba cujo prefixo bate (o "/" só bate exato).
    for (var i = _abas.length - 1; i >= 0; i--) {
      final r = _abas[i].rota;
      if (r == Routes.home ? location == r : location.startsWith(r)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice(location),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) => context.go(_abas[i].rota),
        destinations: [
          for (final a in _abas)
            NavigationDestination(icon: Icon(a.icon), label: a.label),
        ],
      ),
    );
  }
}
