import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/formatting/dates.dart';
import '../../../core/formatting/money_provider.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/help_actions.dart';
import '../application/inventory_providers.dart';
import '../domain/stock_item.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  String _q = '';
  StockTipo? _filtro; // null = tudo

  bool get _podeEditar => ref.read(currentPapelProvider).canEditBusiness;

  Future<void> _abrirAjuste(StockItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AjusteSheet(item: item),
    );
  }

  void _historico(StockItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _HistoricoSheet(item: item),
    );
  }

  Future<void> _novoItemLivre() async {
    final r = await showModalBottomSheet<_ItemLivre>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ItemLivreSheet(),
    );
    if (r == null || r.descricao.isEmpty) return;
    try {
      await ref.read(inventoryActionsProvider).criarItemLivre(
            descricao: r.descricao,
            unidade: r.unidade,
            quantidadeInicial: r.quantidade,
            minimo: r.minimo,
            localizacao: r.localizacao,
          );
      if (mounted) setState(() => _filtro = StockTipo.livre);
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(stockListProvider);
    final fmt = ref.watch(moneyFormatProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventário'),
        actions: const [HelpActions(topic: HelpTopic.inventario)],
      ),
      floatingActionButton: _podeEditar
          ? FloatingActionButton.extended(
              onPressed: _novoItemLivre,
              icon: const Icon(Icons.add),
              label: const Text('Item livre'),
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
                for (final f in [
                  null,
                  StockTipo.ingrediente,
                  StockTipo.ficha,
                  StockTipo.livre,
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(switch (f) {
                        null => 'Tudo',
                        StockTipo.ingrediente => 'Ingredientes',
                        StockTipo.ficha => 'Produtos',
                        StockTipo.livre => 'Outros',
                      }),
                      selected: _filtro == f,
                      onSelected: (_) => setState(() => _filtro = f),
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
                final items = all.where((i) {
                  final mq = _q.isEmpty ||
                      i.nome.toLowerCase().contains(_q.toLowerCase());
                  final mf = _filtro == null || i.tipo == _filtro;
                  return mq && mf;
                }).toList();
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.warehouse_outlined,
                    titulo: 'Nada a mostrar',
                    mensagem: 'Sem itens para este filtro ou pesquisa.',
                  );
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, idx) {
                    final i = items[idx];
                    return ListTile(
                      title: Text(i.nome),
                      subtitle: Text(
                        [
                          switch (i.tipo) {
                            StockTipo.ficha => 'Produto',
                            StockTipo.ingrediente => 'Ingrediente',
                            StockTipo.livre => 'Outro',
                          },
                          if (i.valor > 0) 'valor ${fmt(i.valor)}',
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
                                color: Theme.of(context).colorScheme.error,
                                size: 20,
                              ),
                            ),
                          const SizedBox(width: 6),
                          Text(
                            i.quantidadeLabel(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      onTap: () => _podeEditar
                          ? _abrirAjuste(i)
                          : _historico(i),
                      onLongPress: () => _historico(i),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AjusteSheet extends ConsumerStatefulWidget {
  const _AjusteSheet({required this.item});
  final StockItem item;

  @override
  ConsumerState<_AjusteSheet> createState() => _AjusteSheetState();
}

class _AjusteSheetState extends ConsumerState<_AjusteSheet> {
  final _delta = TextEditingController();
  final _notas = TextEditingController();
  late final _minimo = TextEditingController(
    text: widget.item.minimo > 0
        ? widget.item.minimo.toStringAsFixed(0)
        : '',
  );
  bool _entrada = true;
  MotivoMovimento _motivo = MotivoMovimento.compra;
  bool _motivoTocado = false;
  bool _busy = false;

  void _atualizarDirecao(bool entrada) {
    setState(() {
      _entrada = entrada;
      if (!_motivoTocado) {
        _motivo =
            entrada ? MotivoMovimento.compra : MotivoMovimento.venda;
      }
    });
  }

  @override
  void dispose() {
    _delta.dispose();
    _notas.dispose();
    _minimo.dispose();
    super.dispose();
  }

  Future<void> _aplicar() async {
    final v = double.tryParse(_delta.text.replaceAll(',', '.').trim()) ?? 0;
    final novoMin = double.tryParse(_minimo.text.replaceAll(',', '.').trim());
    if (v == 0 && (novoMin ?? widget.item.minimo) == widget.item.minimo) {
      Navigator.pop(context);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(inventoryActionsProvider).ajustar(
            item: widget.item,
            delta: _entrada ? v : -v,
            motivo: _motivo,
            notas: _notas.text,
            minimo: (novoMin != null && novoMin != widget.item.minimo)
                ? novoMin
                : null,
          );
      if (mounted) Navigator.pop(context);
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final un = widget.item.unidade;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.item.nome,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            'Em stock: ${widget.item.quantidadeLabel()}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Entrada')),
              ButtonSegment(value: false, label: Text('Saída')),
            ],
            selected: {_entrada},
            onSelectionChanged: (s) => _atualizarDirecao(s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _delta,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Quantidade',
              suffixText: un,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<MotivoMovimento>(
            value: _motivo,
            decoration: const InputDecoration(labelText: 'Motivo'),
            items: [
              for (final m in MotivoMovimento.values)
                DropdownMenuItem(value: m, child: Text(m.label)),
            ],
            onChanged: (v) => setState(() {
              _motivo = v ?? MotivoMovimento.ajuste;
              _motivoTocado = true;
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notas,
            decoration: const InputDecoration(labelText: 'Notas (opcional)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _minimo,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Stock mínimo (aviso)',
              suffixText: un,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _aplicar,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Aplicar'),
          ),
        ],
      ),
    );
  }
}

class _HistoricoSheet extends ConsumerWidget {
  const _HistoricoSheet({required this.item});
  final StockItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (
      ingredienteId: item.tipo == StockTipo.ingrediente ? item.id : null,
      fichaId: item.tipo == StockTipo.ficha ? item.id : null,
      descricao: item.tipo == StockTipo.livre ? item.id : null,
    );
    final async = ref.watch(movimentosProvider(key));
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Movimentos · ${item.nome}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: AsyncValueView<List<MovimentoStock>>(
              value: async,
              data: (movs) => movs.isEmpty
                  ? const Center(child: Text('Sem movimentos.'))
                  : ListView.separated(
                      itemCount: movs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final m = movs[i];
                        final entrada = m.delta >= 0;
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            entrada
                                ? Icons.south_west
                                : Icons.north_east,
                            color: entrada
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.error,
                          ),
                          title: Text(
                            '${entrada ? '+' : ''}${m.delta.toStringAsFixed(m.delta % 1 == 0 ? 0 : 1)} '
                            '${item.unidade} · ${m.motivo.label}',
                          ),
                          subtitle: Text(
                            [
                              formatDateTimeShort(m.created),
                              if (m.notas.isNotEmpty) m.notas,
                            ].join(' · '),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

typedef _ItemLivre = ({
  String descricao,
  String unidade,
  double quantidade,
  double minimo,
  String localizacao,
});

/// Folha para criar um item livre no inventário (sabão, sacos de lixo…).
class _ItemLivreSheet extends StatefulWidget {
  const _ItemLivreSheet();

  @override
  State<_ItemLivreSheet> createState() => _ItemLivreSheetState();
}

class _ItemLivreSheetState extends State<_ItemLivreSheet> {
  final _desc = TextEditingController();
  final _qtd = TextEditingController(text: '0');
  final _min = TextEditingController();
  final _local = TextEditingController();
  String _unidade = 'un';

  static const _unidades = ['un', 'caixa', 'pacote', 'litro', 'kg', 'rolo'];

  @override
  void dispose() {
    _desc.dispose();
    _qtd.dispose();
    _min.dispose();
    _local.dispose();
    super.dispose();
  }

  double _n(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.').trim()) ?? 0;

  void _guardar() {
    final d = _desc.text.trim();
    if (d.isEmpty) return;
    Navigator.pop(context, (
      descricao: d,
      unidade: _unidade,
      quantidade: _n(_qtd),
      minimo: _n(_min),
      localizacao: _local.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Novo item livre',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Qualquer coisa da empresa que não seja ingrediente nem produto.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _desc,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nome *'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qtd,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Quantidade atual'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _unidade,
                  decoration: const InputDecoration(labelText: 'Unidade'),
                  items: [
                    for (final u in _unidades)
                      DropdownMenuItem(value: u, child: Text(u)),
                  ],
                  onChanged: (v) => setState(() => _unidade = v ?? 'un'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _min,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration:
                const InputDecoration(labelText: 'Stock mínimo (aviso)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _local,
            decoration:
                const InputDecoration(labelText: 'Localização (opcional)'),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _guardar, child: const Text('Criar')),
        ],
      ),
    );
  }
}
