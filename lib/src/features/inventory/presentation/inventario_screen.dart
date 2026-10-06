import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/help_actions.dart';
import '../../../core/widgets/hub_segmentos.dart';
import '../../consumables/presentation/consumiveis_screen.dart';
import '../../ingredients/presentation/ingredients_screen.dart';
import '../../packaging/presentation/embalagens_screen.dart';
import '../application/comparar_precos_providers.dart';
import '../application/inventory_providers.dart';
import '../data/variacao_preco_repository.dart';
import '../domain/stock_item.dart';
import 'material_loja_screen.dart';
import 'variacoes_preco_view.dart';

/// As secções do Inventário.
enum SecaoInventario {
  ingredientes('Ingredientes', Icons.egg_alt_outlined, Routes.inventory),
  limpeza(
    'Limpeza e insumos',
    Icons.cleaning_services_outlined,
    Routes.inventoryLimpeza,
  ),
  material(
    'Material da loja',
    Icons.chair_alt_outlined,
    Routes.inventoryMaterial,
  ),
  embalagens(
    'Embalagens',
    Icons.inventory_2_outlined,
    Routes.inventoryEmbalagens,
  ),
  precos('Preços', Icons.trending_up, Routes.inventoryPrecos);

  const SecaoInventario(this.label, this.icon, this.rota);
  final String label;
  final IconData icon;
  final String rota;

  HelpTopic get ajuda => switch (this) {
    SecaoInventario.ingredientes => HelpTopic.ingredientes,
    SecaoInventario.limpeza => HelpTopic.consumiveis,
    SecaoInventario.material => HelpTopic.inventario,
    SecaoInventario.embalagens => HelpTopic.embalagens,
    SecaoInventario.precos => HelpTopic.variacoesPreco,
  };

  StockTipo? get tipoStock => switch (this) {
    SecaoInventario.ingredientes => StockTipo.ingrediente,
    SecaoInventario.limpeza => StockTipo.consumivel,
    SecaoInventario.material => StockTipo.livre,
    SecaoInventario.embalagens => null,
    SecaoInventario.precos => null,
  };
}

/// Inventário: tudo o que a empresa compra e guarda numa só página — os
/// ingredientes (com preço e stock), a limpeza e insumos, o material da loja
/// e as embalagens — em secções, com o stock à vista em cada linha.
class InventarioScreen extends ConsumerWidget {
  const InventarioScreen({super.key, required this.secao, this.busca = ''});

  final SecaoInventario secao;

  /// Texto já escrito na pesquisa dos ingredientes (vem do menu "Mais").
  final String busca;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // quantos itens abaixo do mínimo há em cada secção
    final stock = ref.watch(stockPorItemProvider).values;
    int baixos(SecaoInventario s) =>
        stock.where((i) => i.tipo == s.tipoStock && i.stockBaixo).length;

    final subidas = ref.watch(subidasPorVerProvider).length;
    final poupancas = ref.watch(poupancasPossiveisProvider);
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
          HubSegmentos<SecaoInventario>(
            principais: const [
              SecaoInventario.ingredientes,
              SecaoInventario.limpeza,
              SecaoInventario.precos,
            ],
            extras: const [
              SecaoInventario.material,
              SecaoInventario.embalagens,
            ],
            atual: secao,
            rotulo: (s) => switch (s) {
              SecaoInventario.limpeza => 'Limpeza',
              SecaoInventario.material => 'Material da loja',
              _ => s.label,
            },
            icone: (s) => s.icon,
            aoEscolher: (s) => context.go(s.rota),
            // o que está a acabar / a mudar de preço vê-se sem abrir
            emblema: (s) {
              if (s == SecaoInventario.precos) {
                if (subidas > 0) return (texto: '↑$subidas', alerta: true);
                if (poupancas > 0) return (texto: '↓$poupancas', alerta: false);
                return null;
              }
              final n = baixos(s);
              return n > 0 ? (texto: '$n', alerta: true) : null;
            },
          ),
          Expanded(
            child: switch (secao) {
              SecaoInventario.ingredientes => IngredientsScreen(
                key: ValueKey('inv-ingredientes-$busca'),
                embedded: true,
                buscaInicial: busca,
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
              SecaoInventario.precos => const VariacoesPrecoView(
                key: ValueKey('inv-precos'),
              ),
            },
          ),
        ],
      ),
    );
  }
}
