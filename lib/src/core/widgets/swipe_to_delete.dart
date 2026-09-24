import 'package:flutter/material.dart';

/// Deslizar para a esquerda para apagar/mover para a lixeira.
///
/// O item some logo que é deslizado (mesmo que a lista só se atualize depois
/// de o servidor responder) — sem isto o Flutter mostra o ecrã de erro
/// vermelho "A dismissed Dismissible widget is still part of the tree". Se
/// [apagar] devolver `false` (falhou), o item volta.
class SwipeToDelete extends StatefulWidget {
  const SwipeToDelete({
    super.key,
    required this.child,
    required this.confirmar,
    required this.apagar,
  });

  final Widget child;

  /// Pergunta ao utilizador; `true` = pode apagar.
  final Future<bool> Function() confirmar;

  /// Faz a operação; `true` se correu bem.
  final Future<bool> Function() apagar;

  @override
  State<SwipeToDelete> createState() => _SwipeToDeleteState();
}

class _SwipeToDeleteState extends State<SwipeToDelete> {
  bool _removido = false;

  @override
  Widget build(BuildContext context) {
    if (_removido) return const SizedBox.shrink();
    return Dismissible(
      key: const ValueKey('swipe-to-delete'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      confirmDismiss: (_) => widget.confirmar(),
      onDismissed: (_) async {
        setState(() => _removido = true);
        final ok = await widget.apagar();
        if (!ok && mounted) setState(() => _removido = false);
      },
      child: widget.child,
    );
  }
}
