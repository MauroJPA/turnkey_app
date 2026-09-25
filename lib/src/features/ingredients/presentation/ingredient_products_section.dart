import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/ingredients_providers.dart';
import '../data/ingredient_product_repository.dart';
import '../domain/ingredient.dart';
import '../domain/produto_ingrediente.dart';

String _euro(double v) => '${v.toStringAsFixed(2).replaceAll('.', ',')} €';

String _dataCurta(DateTime? d) => d == null
    ? 'sem data'
    : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// "Produtos de compra" de um ingrediente genérico: as marcas/embalagens que se
/// compram. O custo do ingrediente é o do produto com a compra mais recente.
class IngredientProductsSection extends ConsumerWidget {
  const IngredientProductsSection({super.key, required this.ingrediente});

  final Ingrediente ingrediente;

  Future<void> _abrir(
    BuildContext context,
    WidgetRef ref, [
    ProdutoIngrediente? p,
  ]) async {
    final mudou = await showDialog<bool>(
      context: context,
      builder: (_) => _ProdutoDialog(ingrediente: ingrediente, existente: p),
    );
    if (mudou == true) {
      ref.invalidate(produtosIngredienteProvider);
      ref.invalidate(ingredientsListProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final produtos = ref.watch(produtosDoIngredienteProvider(ingrediente.id));
    final atual = produtoMaisRecente(produtos);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Produtos de compra (${produtos.length})', style: tt.titleSmall),
        const SizedBox(height: 4),
        Text(
          'As marcas e embalagens que compras deste ingrediente. O custo é o do '
          'produto com a compra mais recente.',
          style: tt.bodySmall,
        ),
        const SizedBox(height: 8),
        for (final p in produtos)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              title: Text(
                p.marca.isNotEmpty ? '${p.marca} · ${p.nome}' : p.nome,
              ),
              subtitle: Text(
                '${p.resumo} · ${_euro(p.preco)} · ${_dataCurta(p.precoAtualizadoEm)}'
                '${p.fornecedor.isNotEmpty ? ' · ${p.fornecedor}' : ''}',
              ),
              trailing: p.id == atual?.id
                  ? Chip(
                      label: const Text('custo atual'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: cs.primaryContainer,
                    )
                  : null,
              onTap: () => _abrir(context, ref, p),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _abrir(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Adicionar produto'),
          ),
        ),
      ],
    );
  }
}

class _ProdutoDialog extends ConsumerStatefulWidget {
  const _ProdutoDialog({required this.ingrediente, this.existente});

  final Ingrediente ingrediente;
  final ProdutoIngrediente? existente;

  @override
  ConsumerState<_ProdutoDialog> createState() => _ProdutoDialogState();
}

class _ProdutoDialogState extends ConsumerState<_ProdutoDialog> {
  late final _nome = TextEditingController(
    text: widget.existente?.nome ?? widget.ingrediente.nome,
  );
  late final _marca = TextEditingController(
    text: widget.existente?.marca ?? '',
  );
  late final _fornecedor = TextEditingController(
    text: widget.existente?.fornecedor ?? '',
  );
  late final _emb = TextEditingController(
    text: widget.existente == null ? '' : _n(widget.existente!.embalagemG),
  );
  late final _preco = TextEditingController(
    text: widget.existente == null ? '' : _n(widget.existente!.preco),
  );
  bool _busy = false;
  String? _erro;

  static String _n(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
  double _num(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.').trim()) ?? 0;

  @override
  void dispose() {
    _nome.dispose();
    _marca.dispose();
    _fornecedor.dispose();
    _emb.dispose();
    _preco.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_nome.text.trim().isEmpty || _num(_emb) <= 0 || _num(_preco) <= 0) {
      setState(
        () => _erro = 'Indica o nome, o peso da embalagem (g) e o preço.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _erro = null;
    });
    try {
      final repo = ref.read(ingredientProductRepositoryProvider);
      final e = widget.existente;
      // o preço passa a valer a partir de hoje se mudou; se não mudou, mantém a data
      final mudouPreco =
          e == null || e.preco != _num(_preco) || e.embalagemG != _num(_emb);
      if (e == null) {
        await repo.criar(
          ingredienteId: widget.ingrediente.id,
          nome: _nome.text,
          marca: _marca.text,
          fornecedor: _fornecedor.text,
          embalagemG: _num(_emb),
          preco: _num(_preco),
        );
      } else {
        await repo.atualizar(
          e.id,
          nome: _nome.text,
          marca: _marca.text,
          fornecedor: _fornecedor.text,
          embalagemG: _num(_emb),
          preco: _num(_preco),
          data: mudouPreco ? DateTime.now() : e.precoAtualizadoEm,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on Object {
      if (mounted) {
        setState(() => _erro = 'Não foi possível guardar. Tenta de novo.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apagar() async {
    final e = widget.existente;
    if (e == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(ingredientProductRepositoryProvider).apagar(e.id);
      if (mounted) Navigator.pop(context, true);
    } on Object {
      if (mounted) setState(() => _erro = 'Não foi possível apagar.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existente == null ? 'Novo produto' : 'Editar produto'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nome,
              decoration: const InputDecoration(labelText: 'Nome do produto'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _marca,
              decoration: const InputDecoration(labelText: 'Marca'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _fornecedor,
              decoration: const InputDecoration(labelText: 'Fornecedor'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emb,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Embalagem (g)',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _preco,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Preço (€)'),
                  ),
                ),
              ],
            ),
            if (_erro != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _erro!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (widget.existente != null)
          TextButton(
            onPressed: _busy ? null : _apagar,
            child: const Text('Apagar'),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _busy ? null : _guardar,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
