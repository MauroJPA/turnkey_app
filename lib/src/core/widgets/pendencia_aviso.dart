import 'package:flutter/material.dart';

/// Ícone de aviso (vermelho) junto a um preço que ainda não é definitivo —
/// ao passar o rato por cima (hover) ou tocar, explica porquê.
class PendenciaAviso extends StatelessWidget {
  const PendenciaAviso({super.key, required this.mensagem, this.size = 16});

  final String mensagem;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: mensagem,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Preço não é definitivo'),
            content: Text(mensagem),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Entendi'),
              ),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(Icons.warning_amber_rounded, size: size, color: cs.error),
        ),
      ),
    );
  }
}
