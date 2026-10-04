import 'package:flutter/material.dart';

/// Pede o nome de uma categoria (nova, ou o novo nome de uma existente).
/// Devolve `null` se cancelou.
Future<String?> pedirNomeCategoria(
  BuildContext context, {
  String inicial = '',
  String titulo = 'Nova categoria',
  String? dica,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) =>
        _NomeCategoriaDialog(inicial: inicial, titulo: titulo, dica: dica),
  );
}

class _NomeCategoriaDialog extends StatefulWidget {
  const _NomeCategoriaDialog({
    required this.inicial,
    required this.titulo,
    this.dica,
  });

  final String inicial;
  final String titulo;
  final String? dica;

  @override
  State<_NomeCategoriaDialog> createState() => _NomeCategoriaDialogState();
}

class _NomeCategoriaDialogState extends State<_NomeCategoriaDialog> {
  late final _ctrl = TextEditingController(text: widget.inicial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _ok() {
    final n = _ctrl.text.trim();
    if (n.isNotEmpty) Navigator.pop(context, n);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            maxLength: 60,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nome'),
            onSubmitted: (_) => _ok(),
          ),
          if (widget.dica != null)
            Text(widget.dica!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _ok, child: const Text('Guardar')),
      ],
    );
  }
}
