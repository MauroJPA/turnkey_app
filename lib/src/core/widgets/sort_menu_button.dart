import 'package:flutter/material.dart';

/// Um critério de ordenação para uma lista de [T].
class SortOption<T> {
  const SortOption(this.label, this.comparator);

  final String label;
  final Comparator<T> comparator;
}

/// Botão de ordenação reutilizável para ecrãs de lista.
///
/// Toca num critério para o escolher (ordem ascendente); toca outra vez no
/// mesmo critério para inverter a ordem.
class SortMenuButton<T> extends StatelessWidget {
  const SortMenuButton({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.ascending,
    required this.onChanged,
  });

  final List<SortOption<T>> options;
  final int selectedIndex;
  final bool ascending;
  final void Function(int index, bool ascending) onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Ordenar por ${options[selectedIndex].label}',
      icon: Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward),
      onSelected: (i) {
        onChanged(i, i == selectedIndex ? !ascending : true);
      },
      itemBuilder: (_) => [
        for (var i = 0; i < options.length; i++)
          PopupMenuItem(
            value: i,
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: i == selectedIndex
                      ? Icon(
                          ascending ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 17,
                        )
                      : null,
                ),
                const SizedBox(width: 6),
                Text(options[i].label),
              ],
            ),
          ),
      ],
    );
  }
}

/// Aplica um [SortOption] a [items], devolvendo uma nova lista ordenada.
List<T> ordenarPor<T>(List<T> items, SortOption<T> option, bool ascending) {
  final sorted = [...items]..sort(option.comparator);
  if (!ascending) return sorted.reversed.toList();
  return sorted;
}
