import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/help_actions.dart';
import '../../consumables/presentation/consumiveis_screen.dart';
import '../../ingredients/presentation/ingredients_screen.dart';
import '../../packaging/presentation/embalagens_screen.dart';
import '../application/inventory_providers.dart';
import '../domain/stock_item.dart';
import 'material_loja_screen.dart';

/// As secções do Inventário.
enum SecaoInventario {
  ingredientes('Ingredientes', Icons.egg_alt_outlined, Routes.inventory),
  limpeza('Limpeza e insumos', Icons.cleaning_services_outlined,
      Routes.inventoryLimpeza),
  material('Material da loja', Icons.chair_alt_outlined,
      Routes.inventoryMaterial),
  embalagens('Embalagens', Icons.inventory_2_outlined,
      Routes.inventoryEmbalagens);

  const SecaoInventario(this.label, this.icon, this.rota);
  final String label;
  final IconData icon;
  final String rota;

  HelpTopic get ajuda => switch (this) {
    SecaoInventario.ingredientes => HelpTopic.ingredientes,
    SecaoInventario.limpeza => HelpTopic.consumiveis,
    SecaoInventario.material => HelpTopic.inventario,
    SecaoInventario.embalagens => HelpTopic.embalagens,
  };

  StockTipo? get tipoStock => switch (this) {
    SecaoInventario.ingredientes => StockTipo.ingrediente,
    SecaoInventario.limpeza => StockTipo.consumivel,
    SecaoInventario.material => StockTipo.livre,
    SecaoInventario.embalagens => null,
  };
}

/// Inventário: tudo o que a empresa compra e guarda numa só página — os
/// ingredientes (com preço e stock), a limpeza e insumos, o material da loja
/// e as embalagens — em secções, com o stock à vista em cada linha.
class InventarioScreen extends ConsumerWidget {
  const InventarioScreen({super.key, required this.secao});

  final SecaoInventario secao;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // quantos itens abaixo do mínimo há em cada secção
    final stock = ref.watch(stockPorItemProvider).values;
    int baixos(SecaoInventario s) => stock
        .where((i) => i.tipo == s.tipoStock && i.stockBaixo)
        .length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
        title: const Text('Inventário'),
        actions: [HelpActions(topic: secao.ajuda)],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final s in SecaoInventario.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: Icon(s.icon, size: 18),
                      label: Text(
                        baixos(s) > 0
                            ? '${s.label} · ${baixos(s)} a acabar'
                            : s.label,
                      ),
                      selected: secao == s,
                      onSelected: (_) {
                        if (secao != s) context.go(s.rota);
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: switch (secao) {
              SecaoInventario.ingredientes => const IngredientsScreen(
                key: ValueKey('inv-ingredientes'),
                embedded: true,
              ),
              SecaoInventario.limpeza => const ConsumiveisScreen(
                key: ValueKey('inv-limpeza'),
                embedded: true,
              ),
              SecaoInventario.material => const MaterialLojaScreen(
                key: ValueKey('inv-material'),
                embedded: true,
              ),
              SecaoInventario.embalagens => const EmbalagensScreen(
                key: ValueKey('inv-embalagens'),
                embedded: true,
              ),
            },
          ),
        ],
      ),
    );
  }
}
