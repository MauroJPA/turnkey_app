import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/current_user.dart';
import '../../settings/application/empresa_providers.dart';

/// Página "Opções" — ponto de entrada para as secções da Fase 1.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const _sections = <_Section>[
    _Section('Ingredientes', Icons.egg_alt_outlined, Routes.ingredients),
    _Section('Receitas', Icons.menu_book_outlined, Routes.recipes),
    _Section('Fichas Técnicas', Icons.receipt_long_outlined, Routes.techSheets),
    _Section('Produzir', Icons.scale_outlined, Routes.production),
    _Section('Agenda', Icons.event_note_outlined, Routes.schedule),
    _Section('Inventário', Icons.warehouse_outlined, Routes.inventory),
    _Section('Configurações', Icons.settings_outlined, Routes.settings),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final empresa = ref.watch(currentEmpresaProvider);
    final userName = ref.watch(currentUserNameProvider);
    final papel = ref.watch(currentPapelProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          empresa.maybeWhen(
            data: (e) => e?.nome ?? 'Turnkey',
            orElse: () => 'Turnkey',
          ),
        ),
        actions: [
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns = (constraints.maxWidth ~/ 220).clamp(1, 4);
          return GridView.count(
            padding: const EdgeInsets.all(16),
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              for (final s in _sections)
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
