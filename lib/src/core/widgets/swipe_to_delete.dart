import 'package:flutter/material.dart';

import 'desfazer.dart';

/// Deslizar para a esquerda para apagar/mover para a lixeira.
///
/// O item some logo que é deslizado (mesmo que a lista só se atualize depois
/// de o servidor responder) — sem isto o Flutter mostra o ecrã de erro
/// vermelho "A dismissed Dismissible widget is still part of the tree". Se
/// [apagar] devolver `false` (falhou), o item volta.
///
/// Sem [confirmar], apaga logo; com [desfazer] aparece "Desfazer" uns segundos
/// (para o que se pode repor, como mover para a lixeira).
class SwipeToDelete extends StatefulWidget {
  const SwipeToDelete({
    super.key,
    required this.child,
    this.confirmar,
    required this.apagar,
    this.mensagemDesfazer,
    this.desfazer,
  });

  final Widget child;

  /// Pergunta ao utilizador; `true` = pode apagar. `null` = não pergunta.
  final Future<bool> Function()? confirmar;

  /// Faz a operação; `true` se correu bem.
  final Future<bool> Function() apagar;

  /// O texto e a ação do "Desfazer" (repor o que se apagou).
  final String? mensagemDesfazer;
  final Future<void> Function()? desfazer;

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
      confirmDismiss: widget.confirmar == null
          ? null
          : (_) => widget.confirmar!(),
      onDismissed: (_) async {
        // guarda-se já: depois de apagar o ecrã pode ter deixado de existir
        final messenger = ScaffoldMessenger.of(context);
        setState(() => _removido = true);
        final ok = await widget.apagar();
        if (!ok && mounted) setState(() => _removido = false);
        if (ok && widget.desfazer != null) {
          await mostrarDesfazerEm(
            messenger,
            mensagem: widget.mensagemDesfazer ?? 'Apagado',
            desfazer: widget.desfazer!,
          );
        }
      },
      child: widget.child,
    );
  }
}
