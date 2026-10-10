import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/async_value_view.dart';
import '../../consumables/application/consumivel_providers.dart';
import '../../ingredients/application/ingredients_providers.dart';
import '../../packaging/application/embalagem_kit_providers.dart';
import '../../packaging/application/embalagem_providers.dart';
import '../application/recipes_providers.dart';

enum PickedKind {
  ingrediente,
  subReceita,
  embalagem,
  kit,

  /// Artigo do Inventário → Limpeza e insumos (bebidas e revenda).
  revenda,
}

class PickedItem {
  PickedItem({
    required this.kind,
    required this.id,
    required this.nome,
    required this.quantidadeG,
  });
  final PickedKind kind;
  final String id;
  final String nome;
  final double quantidadeG;
}

/// Escolhe um ingrediente / sub-receita / embalagem e a quantidade.
/// Se [apenasVincular] for `true`, não pergunta a quantidade (devolve 0).
/// Se [apenasEmbalagem] for `true`, mostra só embalagens (para o slot de
/// embalagem da ficha técnica). Com [comRevenda], junta o separador
/// "Revenda" (bebidas e outros artigos do Inventário → Limpeza e insumos);
/// [paraRevenda] abre logo nele.
Future<PickedItem?> showItemPickerSheet(
  BuildContext context, {
  String? excludeRecipeId,
  bool apenasVincular = false,
  bool apenasEmbalagem = false,
  bool comRevenda = false,
  bool paraRevenda = false,
}) {
  return showModalBottomSheet<PickedItem>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ItemPickerSheet(
      excludeRecipeId: excludeRecipeId,
      apenasVincular: apenasVincular,
      apenasEmbalagem: apenasEmbalagem,
      comRevenda: comRevenda || paraRevenda,
      paraRevenda: paraRevenda,
    ),
  );
}

class _ItemPickerSheet extends ConsumerStatefulWidget {
  const _ItemPickerSheet({
    this.excludeRecipeId,
    this.apenasVincular = false,
    this.apenasEmbalagem = false,
    this.comRevenda = false,
    this.paraRevenda = false,
  });
  final String? excludeRecipeId;
  final bool apenasVincular;
  final bool apenasEmbalagem;
  final bool comRevenda;
  final bool paraRevenda;

  @override
  ConsumerState<_ItemPickerSheet> createState() => _ItemPickerSheetState();
}

class _ItemPickerSheetState extends ConsumerState<_ItemPickerSheet> {
  late PickedKind _kind = widget.apenasEmbalagem
      ? PickedKind.embalagem
      : widget.paraRevenda
      ? PickedKind.revenda
      : PickedKind.ingrediente;
  String _q = '';

  Future<PickedItem?> _askQty(
    PickedKind kind,
    String id,
    String nome, {
    String unidade = 'g',
  }) async {
    if (widget.apenasVincular) {
      return PickedItem(kind: kind, id: id, nome: nome, quantidadeG: 0);
    }
    final ehEmb = kind == PickedKind.embalagem || kind == PickedKind.kit;
    if (kind == PickedKind.revenda) unidade = 'un';
    final ctrl = TextEditingController(
      text: ehEmb || kind == PickedKind.revenda ? '1' : '',
    );
    final qtd = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Quantidade — $nome'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: kind == PickedKind.kit
                ? 'Kits por unidade de produto'
                : ehEmb
                ? 'Peças por unidade de produto'
                : switch (unidade) {
                    'ml' => 'Mililitros (ml)',
                    'un' => 'Unidades',
                    _ => 'Gramas',
                  },
          ),
          onSubmitted: (_) => Navigator.pop(
            ctx,
            double.tryParse(ctrl.text.replaceAll(',', '.')),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              double.tryParse(ctrl.text.replaceAll(',', '.')),
            ),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
    if (qtd == null || qtd <= 0) return null;
    return PickedItem(kind: kind, id: id, nome: nome, quantidadeG: qtd);
  }

  @override
  Widget build(BuildContext context) {
    final ingredientes = ref.watch(ingredientsListProvider(false));
    final receitas = ref.watch(recipesListProvider(false));
    final embalagens = ref.watch(embalagensListProvider);
    final kits = ref.watch(embalagemKitsListProvider);
    final consumiveis = widget.comRevenda
        ? ref.watch(consumiveisListProvider)
        : null;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            if (widget.apenasEmbalagem)
              SegmentedButton<PickedKind>(
                segments: const [
                  ButtonSegment(
                    value: PickedKind.embalagem,
                    label: Text('Embalagens'),
                  ),
                  ButtonSegment(value: PickedKind.kit, label: Text('Kits')),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              )
            else
              SegmentedButton<PickedKind>(
                segments: [
                  if (widget.paraRevenda)
                    const ButtonSegment(
                      value: PickedKind.revenda,
                      label: Text('Revenda'),
                    ),
                  const ButtonSegment(
                    value: PickedKind.ingrediente,
                    label: Text('Ingredientes'),
                  ),
                  const ButtonSegment(
                    value: PickedKind.subReceita,
                    label: Text('Receitas'),
                  ),
                  if (widget.comRevenda && !widget.paraRevenda)
                    const ButtonSegment(
                      value: PickedKind.revenda,
                      label: Text('Revenda'),
                    ),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Procurar',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _kind == PickedKind.revenda && consumiveis != null
                  ? AsyncValueView(
                      value: consumiveis,
                      data: (all) {
                        final q = _q.toLowerCase();
                        bool deRevenda(String c) {
                          final x = c.toLowerCase();
                          return x.startsWith('bebida') ||
                              x.startsWith('revenda');
                        }

                        // bebidas e revenda primeiro; depois o resto
                        final items =
                            all
                                .where(
                                  (c) =>
                                      c.nomeComCaracteristica
                                          .toLowerCase()
                                          .contains(q) ||
                                      c.categoria.toLowerCase().contains(q),
                                )
                                .toList()
                              ..sort((a, b) {
                                final ra = deRevenda(a.categoria) ? 0 : 1;
                                final rb = deRevenda(b.categoria) ? 0 : 1;
                                if (ra != rb) return ra - rb;
                                return a.nome.toLowerCase().compareTo(
                                  b.nome.toLowerCase(),
                                );
                              });
                        if (items.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Sem artigos. Cria-os em Inventário → Limpeza e '
                                'insumos (categoria Bebida ou Revenda), ou entra '
                                'uma fatura com eles.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }
                        return ListView(
                          children: [
                            for (final c in items)
                              ListTile(
                                title: Text(c.nomeComCaracteristica),
                                subtitle: Text(
                                  [
                                    c.categoria,
                                    if (c.preco > 0)
                                      '€ ${c.preco.toStringAsFixed(2)}/un'
                                    else
                                      'sem preço',
                                    if (c.fornecedor.isNotEmpty) c.fornecedor,
                                  ].join(' · '),
                                ),
                                onTap: () async {
                                  final r = await _askQty(
                                    PickedKind.revenda,
                                    c.id,
                                    c.nomeComCaracteristica,
                                  );
                                  if (r != null && context.mounted) {
                                    Navigator.pop(context, r);
                                  }
                                },
                              ),
                          ],
                        );
                      },
                    )
                  : _kind == PickedKind.kit
                  ? AsyncValueView(
                      value: kits,
                      data: (all) {
                        final items = all
                            .where(
                              (k) => k.nome.toLowerCase().contains(
                                _q.toLowerCase(),
                              ),
                            )
                            .toList();
                        if (items.isEmpty) {
                          return const Center(
                            child: Text(
                              'Sem kits. Cria em Início → Embalagens → Kits.',
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        return ListView(
                          children: [
                            for (final k in items)
                              ListTile(
                                title: Text(k.nome),
                                subtitle: Text(
                                  [
                                    if (k.descricao.isNotEmpty) k.descricao,
                                    '≈ € ${k.custoUnitario.toStringAsFixed(4)}/un',
                                  ].join(' · '),
                                ),
                                onTap: () async {
                                  final r = await _askQty(
                                    PickedKind.kit,
                                    k.id,
                                    k.nome,
                                  );
                                  if (r != null && context.mounted) {
                                    Navigator.pop(context, r);
                                  }
                                },
                              ),
                          ],
                        );
                      },
                    )
                  : _kind == PickedKind.embalagem
                  ? AsyncValueView(
                      value: embalagens,
                      data: (all) {
                        final items = all
                            .where(
                              (e) => e.nome.toLowerCase().contains(
                                _q.toLowerCase(),
                              ),
                            )
                            .toList();
                        if (items.isEmpty) {
                          return const Center(
                            child: Text(
                              'Sem embalagens. Cria em Início → Embalagens.',
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        return ListView(
                          children: [
                            for (final e in items)
                              ListTile(
                                title: Text(e.nome),
                                subtitle: Text(
                                  [
                                    if (e.tipo.isNotEmpty) e.tipo,
                                    '≈ € ${e.custoUnidade.toStringAsFixed(4)}/un',
                                  ].join(' · '),
                                ),
                                onTap: () async {
                                  final r = await _askQty(
                                    PickedKind.embalagem,
                                    e.id,
                                    e.nome,
                                  );
                                  if (r != null && context.mounted) {
                                    Navigator.pop(context, r);
                                  }
                                },
                              ),
                          ],
                        );
                      },
                    )
                  : _kind == PickedKind.ingrediente
                  ? AsyncValueView(
                      value: ingredientes,
                      data: (all) {
                        final items = all
                            .where((i) => i.correspondeABusca(_q))
                            .toList();
                        return ListView(
                          children: [
                            for (final i in items)
                              ListTile(
                                title: Text(i.nomeComCaracteristica),
                                subtitle: Text(
                                  [
                                    if (i.un != 'g') 'em ${i.un}',
                                    if (i.fornecedor.isNotEmpty) i.fornecedor,
                                  ].join(' · '),
                                ),
                                onTap: () async {
                                  final r = await _askQty(
                                    PickedKind.ingrediente,
                                    i.id,
                                    i.nomeComCaracteristica,
                                    unidade: i.un,
                                  );
                                  if (r != null && context.mounted) {
                                    Navigator.pop(context, r);
                                  }
                                },
                              ),
                          ],
                        );
                      },
                    )
                  : AsyncValueView(
                      value: receitas,
                      data: (all) {
                        final items = all
                            .where(
                              (r) =>
                                  r.id != widget.excludeRecipeId &&
                                  r.nome.toLowerCase().contains(
                                    _q.toLowerCase(),
                                  ),
                            )
                            .toList();
                        return ListView(
                          children: [
                            for (final r in items)
                              ListTile(
                                title: Text(r.nome),
                                subtitle: Text(r.categoria),
                                onTap: () async {
                                  final res = await _askQty(
                                    PickedKind.subReceita,
                                    r.id,
                                    r.nome,
                                  );
                                  if (res != null && context.mounted) {
                                    Navigator.pop(context, res);
                                  }
                                },
                              ),
                          ],
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
