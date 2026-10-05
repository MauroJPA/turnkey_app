import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/errors/mensagem_amigavel.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/help_actions.dart';
import '../application/inventory_providers.dart';
import '../domain/stock_item.dart';
import 'stock_sheets.dart';

enum _Vista { tudo, favoritos, maisUsados }

/// Material da loja: o inventário geral — equipamentos, mobiliário,
/// ferramentas, o que se usa e não é ingrediente nem produto. Agrupado por
/// categoria, com entradas e saídas de stock.
class MaterialLojaScreen extends ConsumerStatefulWidget {
  const MaterialLojaScreen({super.key, this.embedded = false});

  /// Dentro da página Inventário: sem barra própria (só as ações).
  final bool embedded;

  @override
  ConsumerState<MaterialLojaScreen> createState() => _MaterialLojaScreenState();
}

class _MaterialLojaScreenState extends ConsumerState<MaterialLojaScreen> {
  String _q = '';
  _Vista _vista = _Vista.tudo;

  bool get _podeEditar => ref.read(currentPapelProvider).canEditBusiness;

  List<StockItem> _aplicarVista(List<StockItem> xs) {
    final q = _q.toLowerCase();
    final out = xs.where((i) {
      final mq =
          q.isEmpty ||
          i.nome.toLowerCase().contains(q) ||
          i.categoria.toLowerCase().contains(q);
      final mv = switch (_vista) {
        _Vista.tudo => true,
        _Vista.favoritos => i.favorito,
        _Vista.maisUsados => i.usos > 0,
      };
      return mq && mv;
    }).toList();
    if (_vista == _Vista.maisUsados) {
      out.sort((a, b) {
        final c = b.usos.compareTo(a.usos);
        return c != 0 ? c : b.ultimoUso.compareTo(a.ultimoUso);
      });
    }
    return out;
  }

  Future<void> _novoItem() async {
    final r = await showItemLivreSheet(context);
    if (r == null || r.descricao.isEmpty) return;
    try {
      await ref
          .read(inventoryActionsProvider)
          .criarItemLivre(
            descricao: r.descricao,
            unidade: r.unidade,
            categoria: r.categoria,
            quantidadeInicial: r.quantidade,
            minimo: r.minimo,
            localizacao: r.localizacao,
          );
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(stockListProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go(Routes.home),
              ),
              title: const Text('Material da loja'),
              actions: const [HelpActions(topic: HelpTopic.inventario)],
            ),
      floatingActionButton: _podeEditar
          ? FloatingActionButton.extended(
              onPressed: _novoItem,
              icon: const Icon(Icons.add),
              label: const Text('Material'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Procurar',
                isDense: true,
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final v in _Vista.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: switch (v) {
                        _Vista.favoritos => const Icon(Icons.star, size: 18),
                        _Vista.maisUsados => const Icon(
                          Icons.trending_up,
                          size: 18,
                        ),
                        _ => null,
                      },
                      label: Text(switch (v) {
                        _Vista.tudo => 'Tudo',
                        _Vista.favoritos => 'Favoritos',
                        _Vista.maisUsados => 'Mais usados',
                      }),
                      selected: _vista == v,
                      onSelected: (_) => setState(() => _vista = v),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AsyncValueView<List<StockItem>>(
              value: async,
              onRetry: () => ref.invalidate(stockListProvider),
              data: (all) {
                final items = _aplicarVista([
                  for (final i in all)
                    if (i.tipo == StockTipo.livre) i,
                ]);
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.warehouse_outlined,
                    titulo: 'Nada a mostrar',
                    mensagem: switch (_vista) {
                      _Vista.favoritos =>
                        'Ainda não marcaste favoritos (toca na estrela de um item).',
                      _Vista.maisUsados =>
                        'Ainda não há utilizações registadas.',
                      _Vista.tudo =>
                        _q.isEmpty
                            ? 'Sem material. Usa o botão "Material" para '
                                  'juntar equipamentos, mobiliário, ferramentas…'
                            : 'Sem itens para esta pesquisa.',
                    },
                  );
                }
                // agrupar por categoria
                final grupos = <String, List<StockItem>>{};
                for (final i in items) {
                  grupos
                      .putIfAbsent(
                        i.categoria.isEmpty ? 'Outro' : i.categoria,
                        () => [],
                      )
                      .add(i);
                }
                final chaves = grupos.keys.toList()..sort();
                return ListView(
                  padding: const EdgeInsets.only(bottom: 88),
                  children: [
                    for (final k in chaves) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                        child: Text(
                          k,
                          style: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(color: cs.primary),
                        ),
                      ),
                      for (final i in grupos[k]!) _linha(i),
                      const Divider(height: 1),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _linha(StockItem i) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: IconButton(
        tooltip: i.favorito ? 'Tirar dos favoritos' : 'Marcar favorito',
        icon: Icon(
          i.favorito ? Icons.star : Icons.star_border,
          color: i.favorito ? cs.tertiary : null,
        ),
        onPressed: () => ref.read(inventoryActionsProvider).alternarFavorito(i),
      ),
      title: Text(i.nome),
      subtitle: Text(
        [
          if (i.usos > 0) 'usado ${i.usos.toStringAsFixed(0)}×',
          if (i.localizacao.isNotEmpty) i.localizacao,
        ].join(' · '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (i.stockBaixo)
            Tooltip(
              message: 'Abaixo do mínimo',
              child: Icon(
                Icons.warning_amber_rounded,
                color: cs.error,
                size: 20,
              ),
            ),
          const SizedBox(width: 6),
          Text(
            i.quantidadeLabel(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      onTap: () => _podeEditar
          ? showAjusteStockSheet(context, i)
          : showHistoricoStockSheet(context, i),
      onLongPress: () => showHistoricoStockSheet(context, i),
    );
  }
}
