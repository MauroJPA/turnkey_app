import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/marcas_fornecedores_providers.dart';
import '../../../core/nutrition/nutrition.dart' show Nutrientes, kAlergenios;
import '../../../core/widgets/autocomplete_text_field.dart';
import '../application/ingredients_providers.dart';
import '../data/ingredient_product_repository.dart';
import '../data/ingredient_repository.dart';
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
                '${p.fornecedor.isNotEmpty ? ' · ${p.fornecedor}' : ''}'
                '${p.alergenios.isNotEmpty ? '\nContém também: ${p.alergenios.join(', ')}' : ''}'
                '${p.alergeniosTracos.isNotEmpty ? '\nPode conter: ${p.alergeniosTracos.join(', ')}' : ''}'
                '${p.nutriPropria ? '\nNutrição própria (${p.nutri.kcal.toStringAsFixed(0)} kcal)' : ''}',
              ),
              isThreeLine:
                  p.alergenios.isNotEmpty ||
                  p.alergeniosTracos.isNotEmpty ||
                  p.nutriPropria,
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
  late final Set<String> _alerg = {...?widget.existente?.alergenios};
  late final Set<String> _tracos = {...?widget.existente?.alergeniosTracos};
  late bool _nutriPropria = widget.existente?.nutriPropria ?? false;
  late String _nutriBase = widget.existente?.nutriBase ?? '100g';
  late final _kcal = _ctrl(widget.existente?.nutri.kcal);
  late final _lip = _ctrl(widget.existente?.nutri.lipidos);
  late final _sat = _ctrl(widget.existente?.nutri.saturados);
  late final _hc = _ctrl(widget.existente?.nutri.hidratos);
  late final _ac = _ctrl(widget.existente?.nutri.acucares);
  late final _fib = _ctrl(widget.existente?.nutri.fibra);
  late final _prot = _ctrl(widget.existente?.nutri.proteina);
  late final _sal = _ctrl(widget.existente?.nutri.sal);
  late final _dens = _ctrl(
    (widget.existente?.nutriDensidade ?? 1) == 1
        ? null
        : widget.existente?.nutriDensidade,
  );
  bool _lendo = false;
  bool _busy = false;
  String? _erro;

  static TextEditingController _ctrl(double? v) =>
      TextEditingController(text: (v == null || v == 0) ? '' : _n(v));

  Nutrientes _nutrientes() => Nutrientes(
    kcal: _num(_kcal),
    lipidos: _num(_lip),
    saturados: _num(_sat),
    hidratos: _num(_hc),
    acucares: _num(_ac),
    fibra: _num(_fib),
    proteina: _num(_prot),
    sal: _num(_sal),
  );

  NutriProduto _nutriProduto() => NutriProduto(
    propria: _nutriPropria,
    nutri: _nutrientes(),
    base: _nutriBase,
    densidade: _num(_dens) > 0 ? _num(_dens) : 1,
  );

  void _preencher(Nutrientes n, {String base = '100g', double densidade = 1}) {
    String t(double v) => v == 0 ? '' : _n(v);
    _kcal.text = t(n.kcal);
    _lip.text = t(n.lipidos);
    _sat.text = t(n.saturados);
    _hc.text = t(n.hidratos);
    _ac.text = t(n.acucares);
    _fib.text = t(n.fibra);
    _prot.text = t(n.proteina);
    _sal.text = t(n.sal);
    _nutriBase = base;
    _dens.text = densidade == 1 ? '' : _n(densidade);
  }

  /// Lê a tabela nutricional do rótulo deste produto por IA (o servidor guarda a chave).
  Future<void> _lerRotulo() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      withData: true,
    );
    final f = (picked != null && picked.files.isNotEmpty)
        ? picked.files.first
        : null;
    if (f == null || f.bytes == null || !mounted) return;
    setState(() => _lendo = true);
    try {
      final r = await ref
          .read(ingredientRepositoryProvider)
          .lerRotulo(bytes: f.bytes!.toList(), nome: f.name);
      if (!mounted) return;
      setState(() {
        _preencher(r.nutri, base: r.base, densidade: r.densidade);
        _nutriPropria = true;
        // os alergénios lidos juntam-se aos deste produto
        _alerg.addAll(r.alergenios);
        _tracos.addAll(r.tracos);
        _erro = null;
      });
    } on Object {
      if (mounted) {
        setState(() => _erro = 'Não foi possível ler o rótulo. Tenta de novo.');
      }
    } finally {
      if (mounted) setState(() => _lendo = false);
    }
  }

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
    for (final c in [_kcal, _lip, _sat, _hc, _ac, _fib, _prot, _sal, _dens]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_nome.text.trim().isEmpty || _num(_emb) <= 0 || _num(_preco) <= 0) {
      setState(
        () => _erro =
            'Indica o nome, o tamanho da embalagem (${widget.ingrediente.un}) e o preço.',
      );
      return;
    }
    if (_nutriPropria && _nutrientes().vazio) {
      setState(
        () => _erro =
            'Preenche a nutrição do produto, ou desliga "Nutrição própria".',
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
          alergenios: _alerg.toList(),
          alergeniosTracos: _tracos.toList(),
          nutri: _nutriProduto(),
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
          alergenios: _alerg.toList(),
          alergeniosTracos: _tracos.toList(),
          nutri: _nutriProduto(),
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

  Widget _campoNutri(String label, TextEditingController c) => TextField(
    controller: c,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label, isDense: true),
  );

  Widget _par(Widget a, Widget b) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(child: a),
        const SizedBox(width: 8),
        Expanded(child: b),
      ],
    ),
  );

  Widget _chips(Set<String> sel) => Wrap(
    spacing: 6,
    runSpacing: 0,
    children: [
      for (final a in kAlergenios)
        FilterChip(
          label: Text(a),
          selected: sel.contains(a),
          visualDensity: VisualDensity.compact,
          onSelected: (v) => setState(() {
            if (v) {
              sel.add(a);
            } else {
              sel.remove(a);
            }
          }),
        ),
    ],
  );

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
            AutocompleteTextField(
              controller: _marca,
              options: ref.watch(marcasConhecidasProvider),
              labelText: 'Marca',
            ),
            const SizedBox(height: 8),
            AutocompleteTextField(
              controller: _fornecedor,
              options: ref.watch(fornecedoresConhecidosProvider),
              labelText: 'Fornecedor',
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
                    decoration: InputDecoration(
                      labelText: 'Embalagem (${widget.ingrediente.un})',
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
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Alergénios a mais neste produto',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Só contam quando uma receita fixa este produto; juntam-se aos '
                'do ingrediente.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 4),
            _chips(_alerg),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Pode conter (vestígios) neste produto',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 4),
            _chips(_tracos),
            const SizedBox(height: 8),
            ExpansionTile(
              key: const ValueKey('nutri-produto'),
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: _nutriPropria,
              leading: const Icon(Icons.local_dining_outlined),
              title: const Text('Nutrição própria do produto'),
              subtitle: const Text(
                'Só conta quando uma receita fixa este produto',
              ),
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Usar estes valores'),
                  subtitle: const Text(
                    'Substituem os do ingrediente nas receitas que fixam '
                    'este produto.',
                  ),
                  value: _nutriPropria,
                  onChanged: (v) => setState(() => _nutriPropria = v),
                ),
                if (_lendo) const LinearProgressIndicator(),
                OutlinedButton.icon(
                  onPressed: _lendo ? null : _lerRotulo,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Foto do rótulo (preencher com IA)'),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: '100g', label: Text('por 100 g')),
                    ButtonSegment(value: '100ml', label: Text('por 100 ml')),
                  ],
                  selected: {_nutriBase},
                  onSelectionChanged: (s) =>
                      setState(() => _nutriBase = s.first),
                ),
                const SizedBox(height: 8),
                _par(
                  _campoNutri('Energia (kcal)', _kcal),
                  _campoNutri('Lípidos (g)', _lip),
                ),
                _par(
                  _campoNutri('saturados (g)', _sat),
                  _campoNutri('Hidratos (g)', _hc),
                ),
                _par(
                  _campoNutri('açúcares (g)', _ac),
                  _campoNutri('Fibra (g)', _fib),
                ),
                _par(
                  _campoNutri('Proteína (g)', _prot),
                  _campoNutri('Sal (g)', _sal),
                ),
                if (_nutriBase == '100ml')
                  _campoNutri('Densidade (g/ml)', _dens),
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
