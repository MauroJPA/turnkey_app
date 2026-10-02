import 'package:flutter/material.dart';

/// Campo de texto livre com sugestões (menu) — para o canal e o método de
/// pagamento de uma venda: escolhe-se uma opção habitual ou escreve-se outra.
class CampoSugestoes extends StatelessWidget {
  const CampoSugestoes({
    super.key,
    required this.controller,
    required this.label,
    required this.sugestoes,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final List<String> sugestoes;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => DropdownMenu<String>(
        controller: controller,
        width: c.maxWidth.isFinite ? c.maxWidth : null,
        label: Text(label),
        enableFilter: false,
        requestFocusOnTap: true,
        dropdownMenuEntries: [
          for (final s in sugestoes) DropdownMenuEntry(value: s, label: s),
        ],
        onSelected: (_) => onChanged?.call(),
      ),
    );
  }
}
