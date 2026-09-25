import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/async_value_view.dart';
import '../application/tech_sheets_providers.dart';
import '../domain/tech_sheet.dart';

/// Abre uma folha para escolher uma ficha técnica (produto de fabrico próprio).
Future<FichaTecnica?> showFichaPickerSheet(BuildContext context) {
  return showModalBottomSheet<FichaTecnica>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _FichaPicker(),
  );
}

class _FichaPicker extends ConsumerStatefulWidget {
  const _FichaPicker();

  @override
  ConsumerState<_FichaPicker> createState() => _FichaPickerState();
}

class _FichaPickerState extends ConsumerState<_FichaPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(fichasListProvider(false));
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Text('Escolher produto',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Procurar ficha técnica',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: AsyncValueView<List<FichaTecnica>>(
                value: async,
                data: (all) {
                  final items = all
                      .where((f) => _q.isEmpty ||
                          f.nome.toLowerCase().contains(_q.toLowerCase()))
                      .toList();
                  if (items.isEmpty) {
                    return const Center(child: Text('Nada encontrado.'));
                  }
                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) => ListTile(
                      title: Text(items[i].nome),
                      subtitle: items[i].categoria.isNotEmpty
                          ? Text(items[i].categoria)
                          : null,
                      onTap: () => Navigator.pop(context, items[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
