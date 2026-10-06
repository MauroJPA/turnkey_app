import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import 'backups_card.dart';
import 'dois_passos_card.dart';

/// Segurança e backups (só administradores): o estado dos backups e o 2.º
/// passo no início de sessão, juntos numa página curta.
class SegurancaScreen extends StatelessWidget {
  const SegurancaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.settings),
        ),
        title: const Text('Segurança e backups'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Estado dos backups',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const BackupsCard(),
          const Divider(height: 28),
          const DoisPassosCard(),
        ],
      ),
    );
  }
}
