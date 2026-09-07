import 'package:flutter/material.dart';

/// Diálogo de confirmação. Devolve `true` se o utilizador confirmar.
Future<bool> confirmDialog(
  BuildContext context, {
  required String titulo,
  required String mensagem,
  String confirmar = 'Confirmar',
  String cancelar = 'Cancelar',
  bool destrutivo = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Text(mensagem),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelar),
        ),
        FilledButton(
          style: destrutivo
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                )
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmar),
        ),
      ],
    ),
  );
  return result ?? false;
}
