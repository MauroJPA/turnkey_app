import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';

/// Conta criada mas ainda não aprovada pelo operador da plataforma.
class PendingApprovalScreen extends ConsumerStatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  ConsumerState<PendingApprovalScreen> createState() =>
      _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends ConsumerState<PendingApprovalScreen> {
  bool _busy = false;

  Future<void> _verificar() async {
    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).reload();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conta em análise'),
        actions: [
          TextButton(
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
            child: const Text('Sair'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.hourglass_top_rounded, size: 48),
                const SizedBox(height: 16),
                Text('A tua conta aguarda aprovação', style: tt.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Recebemos o teu registo. Assim que for aprovado podes criar a '
                  'tua empresa e começar a usar a app. Volta a verificar daqui a '
                  'pouco.',
                  textAlign: TextAlign.center,
                  style: tt.bodyMedium,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _busy ? null : _verificar,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Verificar novamente'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
