import 'package:flutter/material.dart';

/// Estado vazio consistente para ecrãs de lista.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.titulo,
    this.mensagem,
    this.acao,
  });

  final IconData icon;
  final String titulo;
  final String? mensagem;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (mensagem != null) ...[
              const SizedBox(height: 6),
              Text(
                mensagem!,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
            if (acao != null) ...[
              const SizedBox(height: 16),
              acao!,
            ],
          ],
        ),
      ),
    );
  }
}
