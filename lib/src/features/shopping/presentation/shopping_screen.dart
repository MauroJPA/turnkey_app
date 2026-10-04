import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/errors/mensagem_amigavel.dart';
import '../../../core/formatting/money_provider.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/help_actions.dart';
import '../../ingredients/application/ingredients_providers.dart';
import '../../ingredients/data/ingredient_product_repository.dart';
import '../../ingredients/domain/ingredient.dart';
import '../../ingredients/domain/produto_ingrediente.dart';
import '../../inventory/domain/stock_item.dart' show kCategoriasMaterial;
import '../application/shopping_providers.dart';
import '../domain/shopping_item.dart';

class ShoppingScreen extends ConsumerWidget {
  const ShoppingScreen({super.key});

  bool _podeEditar(WidgetRef ref) =>
      ref.read(currentPapelProvider).canEditBusiness;

  Future<void> _reorganizar(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      titulo: 'Reorganizar lista?',
      mensagem:
          'Remove as linhas já compradas (o stock delas já entrou ao dar o '
          'visto) e recalcula o que falta comprar face ao stock atual.',
      confirmar: 'Reorganizar',
    );
    if (!ok) return;
    try {
      final r = await ref.read(shoppingActionsProvider).reorganizar();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${r.removidas} removida(s) · '
              '${r.recalculadas} linha(s) recalculada(s).',
            ),
          ),
        );
      }
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
      }
    }
  }

  Future<void> _limparTudo(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      titulo: 'Limpar toda a lista?',
      mensagem:
          'Apaga todos os itens da lista de compras (comprados e por comprar). '
          'Não altera o inventário. Não é possível desfazer.',
      confirmar: 'Limpar tudo',
      destrutivo: true,
    );
    if (!ok) return;
    try {
      final n = await ref.read(shoppingActionsProvider).limparTudo();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$n item(s) apagado(s).')));
      }
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
      }
    }
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final r = await showModalBottomSheet<_NovoItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _NovoItemSheet(),
    );
    if (r == null || r.descricao.isEmpty) return;
    final a = ref.read(shoppingActionsProvider);
    if (r.ehIngrediente && r.ingredienteId != null) {
      await a.adicionarIngrediente(
        ingredienteId: r.ingredienteId!,
        descricao: r.descricao,
        fornecedor: r.fornecedor,
        quantidadeG: r.quantidade,
        notas: r.notas,
      );
    } else {
      await a.adicionarManual(
        descricao: r.descricao,
        fornecedor: r.fornecedor,
        quantidade: r.quantidade,
        unidade: r.unidade,
        categoria: r.categoria,
        notas: r.notas,
      );
    }
  }

  Future<void> _editarComprar(
    BuildContext context,
    WidgetRef ref,
    ShoppingItem item,
  ) async {
    final ctrl = TextEditingController(text: item.comprarG.toStringAsFixed(0));
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.descricao),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'A comprar',
            suffixText: 'g',
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
              double.tryParse(ctrl.text.replaceAll(',', '.').trim()) ?? 0,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (v == null) return;
    await ref.read(shoppingActionsProvider).editarComprar(item.id, v);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(shoppingListProvider);
    final podeEditar = _podeEditar(ref);
    final fmt = ref.watch(moneyFormatProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
        title: const Text('Lista de compras'),
        actions: [
          IconButton(
            tooltip: 'O que comprei (relatório)',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => context.push(Routes.comprasRelatorio),
          ),
          if (podeEditar)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'reorganizar') _reorganizar(context, ref);
                if (v == 'limpar') _limparTudo(context, ref);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'reorganizar',
                  child: ListTile(
                    leading: Icon(Icons.autorenew),
                    title: Text('Reorganizar lista'),
                    subtitle: Text('Remove comprados e recalcula'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'limpar',
                  child: ListTile(
                    leading: Icon(Icons.delete_sweep_outlined),
                    title: Text('Limpar lista'),
                    subtitle: Text('Apaga tudo'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          const HelpActions(topic: HelpTopic.compras),
        ],
      ),
      floatingActionButton: podeEditar
          ? FloatingActionButton.extended(
              onPressed: () => _add(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Item'),
            )
          : null,
      body: AsyncValueView<List<ShoppingItem>>(
        value: async,
        onRetry: () => ref.invalidate(shoppingListProvider),
        data: (itens) {
          if (itens.isEmpty) {
            return const EmptyState(
              icon: Icons.shopping_cart_outlined,
              titulo: 'Lista de compras vazia',
              mensagem:
                  'Abra uma produção na Agenda e toque em "Adicionar à lista de compras".',
            );
          }
          final grupos = <String, List<ShoppingItem>>{};
          for (final i in itens) {
            grupos.putIfAbsent(i.grupo, () => []).add(i);
          }
          final totalEsperado = itens.fold<double>(
            0,
            (s, i) => s + i.custoEstimado,
          );
          final totalComprado = itens
              .where((i) => i.comprado)
              .fold<double>(0, (s, i) => s + i.custoEstimado);
          final falta = itens.where((i) => !i.comprado).length;

          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              Card(
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _linhaTotal(
                        context,
                        'Total esperado',
                        fmt(totalEsperado),
                        forte: true,
                      ),
                      const SizedBox(height: 4),
                      _linhaTotal(
                        context,
                        'Já comprado (visto)',
                        fmt(totalComprado),
                      ),
                      const SizedBox(height: 4),
                      _linhaTotal(
                        context,
                        'Ainda em falta',
                        '${fmt(totalEsperado - totalComprado)} · '
                            '$falta ${falta == 1 ? 'item' : 'itens'}',
                      ),
                    ],
                  ),
                ),
              ),
              for (final entry in grupos.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    entry.key,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                for (final item in entry.value)
                  _Linha(
                    item: item,
                    podeEditar: podeEditar,
                    fmt: fmt,
                    onToggle: (v) => ref
                        .read(shoppingActionsProvider)
                        .definirComprado(item, v),
                    onEditar: () => _editarComprar(context, ref, item),
                    onRemover: () =>
                        ref.read(shoppingActionsProvider).remover(item.id),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

Widget _linhaTotal(
  BuildContext context,
  String rotulo,
  String valor, {
  bool forte = false,
}) {
  final style = forte
      ? const TextStyle(fontWeight: FontWeight.bold)
      : Theme.of(context).textTheme.bodyMedium;
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(rotulo, style: style),
      Text(valor, style: style),
    ],
  );
}

class _Linha extends StatelessWidget {
  const _Linha({
    required this.item,
    required this.podeEditar,
    required this.fmt,
    required this.onToggle,
    required this.onEditar,
    required this.onRemover,
  });

  final ShoppingItem item;
  final bool podeEditar;
  final MoneyFmt fmt;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEditar;
  final VoidCallback onRemover;

  @override
  Widget build(BuildContext context) {
    final sacos = item.sacos;
    final risca = item.comprado
        ? const TextStyle(decoration: TextDecoration.lineThrough)
        : null;

    final descricao = (sacos != null && sacos > 0)
        ? '$sacos  ${item.descricao}'
        : (!item.emGramas
              ? '${item.quantidadeTexto()}  ${item.descricao}'
              : item.descricao);

    final String detalhe;
    if (!item.emGramas) {
      detalhe = 'Comprar ${item.quantidadeTexto()}';
    } else if (item.necessariaG <= 0) {
      detalhe = 'Comprar ${ShoppingItem.gramasLabel(item.comprarG)}';
    } else if (item.embalagemG > 0) {
      detalhe =
          'Embalagem de ${ShoppingItem.gramasLabel(item.embalagemG)} — '
          'Precisamos de ${ShoppingItem.gramasLabel(item.necessariaG)}';
    } else {
      detalhe =
          'Precisamos de ${ShoppingItem.gramasLabel(item.necessariaG)}'
          ' · comprar ${ShoppingItem.gramasLabel(item.comprarG)}';
    }

    return CheckboxListTile(
      controlAffinity: ListTileControlAffinity.leading,
      value: item.comprado,
      onChanged: podeEditar ? (v) => onToggle(v ?? false) : null,
      isThreeLine: item.notas.isNotEmpty,
      title: Text(descricao, style: risca),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.material ? '${item.categoria} · $detalhe' : detalhe),
          if (item.notas.isNotEmpty)
            Text(
              item.notas,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
        ],
      ),
      secondary: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: podeEditar ? onEditar : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (item.custoEstimado > 0)
                  Text(
                    fmt(item.custoEstimado),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                if (podeEditar)
                  Text('editar', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (podeEditar)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Remover',
              onPressed: onRemover,
            ),
        ],
      ),
    );
  }
}

/// Compara os produtos de compra (marcas/fornecedores) de um ingrediente e,
/// se houver mais do que um com preço, sugere o mais barato e a poupança.
class _ComparacaoFornecedores extends ConsumerWidget {
  const _ComparacaoFornecedores({required this.ingrediente});

  final Ingrediente ingrediente;

  static String _fornecedor(ProdutoIngrediente p) => p.fornecedor.isNotEmpty
      ? p.fornecedor
      : (p.marca.isNotEmpty ? p.marca : p.nome);

  (String unidade, double fator) _unidade() => switch (ingrediente.un) {
    'ml' => ('L', 1000),
    'un' => ('un', 1),
    _ => ('kg', 1000),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final produtos =
        ref
            .watch(produtosDoIngredienteProvider(ingrediente.id))
            .where((p) => p.temPreco)
            .toList()
          ..sort((a, b) => a.custoPorGrama.compareTo(b.custoPorGrama));
    if (produtos.length < 2) return const SizedBox.shrink();

    final barato = produtos.first;
    final caro = produtos.last;
    if (caro.custoPorGrama <= barato.custoPorGrama) {
      return const SizedBox.shrink();
    }
    final (unidade, fator) = _unidade();
    final poupancaPct = (1 - barato.custoPorGrama / caro.custoPorGrama) * 100;
    final fmt = ref.watch(moneyFormatProvider);
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(top: 8),
      color: cs.secondaryContainer,
      child: ListTile(
        dense: true,
        leading: Icon(Icons.lightbulb_outline, color: cs.onSecondaryContainer),
        title: Text(
          '${_fornecedor(barato)} é o mais barato',
          style: TextStyle(color: cs.onSecondaryContainer),
        ),
        subtitle: Text(
          '${fmt(barato.custoPorGrama * fator)}/$unidade · poupas '
          '${poupancaPct.toStringAsFixed(0)}% vs ${_fornecedor(caro)}',
          style: TextStyle(color: cs.onSecondaryContainer),
        ),
        trailing: IconButton(
          tooltip: 'Comparar todos os fornecedores',
          icon: Icon(Icons.info_outline, color: cs.onSecondaryContainer),
          onPressed: () => _mostrarComparacao(context, produtos, fmt),
        ),
      ),
    );
  }

  void _mostrarComparacao(
    BuildContext context,
    List<ProdutoIngrediente> produtos,
    MoneyFmt fmt,
  ) {
    final (unidade, fator) = _unidade();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fornecedores de ${ingrediente.nome}',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Do mais barato para o mais caro, por $unidade.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < produtos.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: i == 0
                      ? Icon(
                          Icons.star,
                          color: Theme.of(ctx).colorScheme.primary,
                        )
                      : const SizedBox(width: 24),
                  title: Text(_fornecedor(produtos[i])),
                  subtitle: produtos[i].resumo.isEmpty
                      ? null
                      : Text(produtos[i].resumo),
                  trailing: Text(
                    '${fmt(produtos[i].custoPorGrama * fator)}/$unidade',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: i == 0 ? Theme.of(ctx).colorScheme.primary : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _NovoItem = ({
  bool ehIngrediente,
  String? ingredienteId,
  String descricao,
  String fornecedor,
  double quantidade, // ingrediente: gramas; material: na unidade
  String unidade,
  String categoria,
  String notas,
});

/// Folha "Novo item" da lista de compras. Primeiro escolhe-se se é um
/// **ingrediente** de receita (entra no stock de ingredientes ao dar o visto)
/// ou **material da loja** (equipamento, consumível, mobiliário… — entra no
/// inventário "Outros" com a categoria escolhida).
class _NovoItemSheet extends ConsumerStatefulWidget {
  const _NovoItemSheet();

  @override
  ConsumerState<_NovoItemSheet> createState() => _NovoItemSheetState();
}

class _NovoItemSheetState extends ConsumerState<_NovoItemSheet> {
  bool _ehIngrediente = true;

  // material
  final _desc = TextEditingController();
  final _forn = TextEditingController();
  final _qtd = TextEditingController(text: '1');
  final _notas = TextEditingController();
  String _unidade = 'un';
  String _categoria = kCategoriasMaterial.first;

  // ingrediente
  final _busca = TextEditingController();
  Ingrediente? _ing;
  String _unidadeIng = 'g'; // g | kg

  static const _unidades = ['un', 'caixa', 'pacote', 'litro', 'kg', 'rolo'];

  @override
  void dispose() {
    _desc.dispose();
    _forn.dispose();
    _qtd.dispose();
    _notas.dispose();
    _busca.dispose();
    super.dispose();
  }

  double _num(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.').trim()) ?? 0;

  void _guardar() {
    if (_ehIngrediente) {
      if (_ing == null) return;
      final g = _num(_qtd) * (_unidadeIng == 'kg' ? 1000 : 1);
      Navigator.pop(context, (
        ehIngrediente: true,
        ingredienteId: _ing!.id,
        descricao: _ing!.nome,
        fornecedor: _ing!.fornecedor,
        quantidade: g,
        unidade: 'g',
        categoria: '',
        notas: _notas.text.trim(),
      ));
      return;
    }
    final d = _desc.text.trim();
    if (d.isEmpty) return;
    Navigator.pop(context, (
      ehIngrediente: false,
      ingredienteId: null,
      descricao: d,
      fornecedor: _forn.text.trim(),
      quantidade: _num(_qtd),
      unidade: _unidade,
      categoria: _categoria,
      notas: _notas.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final valido = _ehIngrediente ? _ing != null : _desc.text.trim().isNotEmpty;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Novo item', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Ingrediente')),
                ButtonSegment(value: false, label: Text('Material da loja')),
              ],
              selected: {_ehIngrediente},
              onSelectionChanged: (s) =>
                  setState(() => _ehIngrediente = s.first),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _ehIngrediente
                  ? _corpoIngrediente()
                  : SingleChildScrollView(child: _corpoMaterial()),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: valido ? _guardar : null,
              child: const Text('Adicionar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _corpoIngrediente() {
    if (_ing != null) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Ingrediente'),
              child: Row(
                children: [
                  Expanded(child: Text(_ing!.nome)),
                  TextButton(
                    onPressed: () => setState(() => _ing = null),
                    child: const Text('mudar'),
                  ),
                ],
              ),
            ),
            _ComparacaoFornecedores(ingrediente: _ing!),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qtd,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Quantidade'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _unidadeIng,
                    decoration: const InputDecoration(labelText: 'Unidade'),
                    items: const [
                      DropdownMenuItem(value: 'g', child: Text('g')),
                      DropdownMenuItem(value: 'kg', child: Text('kg')),
                    ],
                    onChanged: (v) => setState(() => _unidadeIng = v ?? 'g'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notas,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nota (opcional)',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      );
    }
    final async = ref.watch(ingredientsListProvider(false));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _busca,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Procurar ingrediente',
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(mensagemAmigavel(e))),
            data: (todos) {
              final itens = todos
                  .where((i) => i.correspondeABusca(_busca.text))
                  .toList();
              if (itens.isEmpty) {
                return const Center(child: Text('Sem ingredientes.'));
              }
              return ListView.builder(
                itemCount: itens.length,
                itemBuilder: (_, i) => ListTile(
                  dense: true,
                  title: Text(itens[i].nome),
                  subtitle: Text(
                    [
                      if (itens[i].marca.isNotEmpty) itens[i].marca,
                      if (itens[i].fornecedor.isNotEmpty) itens[i].fornecedor,
                    ].join(' · '),
                  ),
                  onTap: () => setState(() => _ing = itens[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _corpoMaterial() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _desc,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'O que comprar *',
            hintText: 'Ex.: bancada inox, faca de chef, sabão',
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _categoria,
          decoration: const InputDecoration(labelText: 'Categoria'),
          items: [
            for (final c in kCategoriasMaterial)
              DropdownMenuItem(value: c, child: Text(c)),
          ],
          onChanged: (v) =>
              setState(() => _categoria = v ?? kCategoriasMaterial.first),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _forn,
          decoration: const InputDecoration(labelText: 'Fornecedor / loja'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _qtd,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Quantidade'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _unidade,
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
          controller: _notas,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nota (opcional)',
            hintText: 'Ex.: tesoura de bico fino — a faca demora muito',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}
