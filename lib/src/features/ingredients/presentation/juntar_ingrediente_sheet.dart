import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ingredient_product_repository.dart';
import '../domain/ingredient.dart';

/// Escolhe o ingrediente que vai ficar (o destino) ao juntar [origem] com outro.
/// Devolve `null` se se cancelar.
Future<Ingrediente?> escolherDestinoJuntar(
  BuildContext context, {
  required Ingrediente origem,
  required List<Ingrediente> todos,
}) => showModalBottomSheet<Ingrediente>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _EscolherDestino(origem: origem, todos: todos),
);

class _EscolherDestino extends ConsumerStatefulWidget {
  const _EscolherDestino({required this.origem, required this.todos});

  final Ingrediente origem;
  final List<Ingrediente> todos;

  @override
  ConsumerState<_EscolherDestino> createState() => _EscolherDestinoState();
}

class _EscolherDestinoState extends ConsumerState<_EscolherDestino> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final produtos = ref.watch(produtosIngredienteProvider).valueOrNull ?? [];
    final itens = [
      for (final i in widget.todos)
        if (i.id != widget.origem.id &&
            i.origem != OrigemIngrediente.fabricoProprio &&
            i.correspondeABusca(_q))
          i,
    ];
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Juntar «${widget.origem.nome}» com…',
                  style: tt.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Escolhe o ingrediente que fica. «${widget.origem.nome}» '
                  'passa a ser um produto de compra dele.',
                  style: tt.bodySmall,
                ),
                const SizedBox(height: 8),
                TextField(
                  autofocus: true,
                  onChanged: (v) => setState(() => _q = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Procurar ingrediente',
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: itens.isEmpty
                ? const Center(child: Text('Nenhum ingrediente.'))
                : ListView.builder(
                    itemCount: itens.length,
                    itemBuilder: (_, k) {
                      final n = produtos
                          .where((p) => p.ingredienteId == itens[k].id)
                          .length;
                      return ListTile(
                        title: Text(itens[k].nome),
                        subtitle: Text(
                          [
                            if (itens[k].marca.isNotEmpty) itens[k].marca,
                            '$n produto(s) de compra',
                          ].join(' · '),
                        ),
                        onTap: () => Navigator.pop(context, itens[k]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
