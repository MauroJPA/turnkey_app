import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';

/// Página "Opções" — ponto de entrada para as secções da Fase 1.
/// As secções em si entram nos milestones seguintes.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = <_Section>[
      const _Section('Ingredientes', Icons.egg_alt_outlined, Routes.ingredients),
      const _Section('Receitas', Icons.menu_book_outlined, Routes.recipes),
      const _Section(
        'Fichas Técnicas',
        Icons.receipt_long_outlined,
        Routes.techSheets,
      ),
      const _Section('Configurações', Icons.settings_outlined, Routes.settings),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Turnkey')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth ~/ 220;
          return GridView.count(
            padding: const EdgeInsets.all(16),
            crossAxisCount: columns.clamp(1, 4),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              for (final s in sections)
                Card(
                  child: InkWell(
                    onTap: () => context.go(s.route),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(s.icon, size: 32),
                          const SizedBox(height: 8),
                          Text(s.label),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Section {
  const _Section(this.label, this.icon, this.route);
  final String label;
  final IconData icon;
  final String route;
}
