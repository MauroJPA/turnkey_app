import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nutrition/nutrition.dart';
import '../application/ingredients_providers.dart';
import '../data/ingredient_product_repository.dart';
import '../data/ingredient_repository.dart';
import '../domain/ingredient.dart';
import '../domain/nutri_ingresso.dart';
import 'ingredient_products_section.dart';
import 'nutricao_sheet.dart';

/// Folha de baixo para criar/editar um ingrediente. Ao criar, também se pode
/// já preencher a informação nutricional (opcional).
/// Devolve um [IngredienteFormResultado] ou `null` se cancelado.
Future<IngredienteFormResultado?> showIngredientFormSheet(
  BuildContext context, {
  Ingrediente? existente,
}) {
  return showModalBottomSheet<IngredienteFormResultado>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _IngredientFormSheet(existente: existente),
  );
}

class _IngredientFormSheet extends ConsumerStatefulWidget {
  const _IngredientFormSheet({this.existente});

  final Ingrediente? existente;

  @override
  ConsumerState<_IngredientFormSheet> createState() =>
      _IngredientFormSheetState();
}

class _IngredientFormSheetState extends ConsumerState<_IngredientFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.existente?.nome ?? '');
  late final _caracteristica = TextEditingController(
    text: widget.existente?.caracteristica ?? '',
  );
  late final _marca = TextEditingController(
    text: widget.existente?.marca ?? '',
  );
  late final _nomeRotulo = TextEditingController(
    text: widget.existente?.nomeRotulo ?? '',
  );
  late final _fornecedor = TextEditingController(
    text: widget.existente?.fornecedor ?? '',
  );
  late final _preco = TextEditingController(
    text: widget.existente == null ? '' : _n(widget.existente!.preco),
  );
  late final _gramas = TextEditingController(
    text: widget.existente == null ? '' : _n(widget.existente!.gramasEmbalagem),
  );
  late OrigemIngrediente _origem =
      widget.existente?.origem ?? OrigemIngrediente.comprado;
  late bool _disponivel = widget.existente?.disponivel ?? true;

  // Nutrição (só ao criar), por 100 g / 100 ml.
  final _kcal = TextEditingController();
  final _lip = TextEditingController();
  final _sat = TextEditingController();
  final _hc = TextEditingController();
  final _ac = TextEditingController();
  final _fib = TextEditingController();
  final _prot = TextEditingController();
  final _sal = TextEditingController();
  String _baseNutri = '100g';
  double _densidade = 1;
  final _alerg = <String>{};
  final _tracos = <String>{};
  String _origemNutri = 'manual';
  ({String nome, List<int> bytes})? _foto;
  bool _lendo = false;
  bool _abrirNutricao = false;

  static String _n(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    for (final c in [
      _nome,
      _caracteristica,
      _marca,
      _nomeRotulo,
      _fornecedor,
      _preco,
      _gramas,
      _kcal,
      _lip,
      _sat,
      _hc,
      _ac,
      _fib,
      _prot,
      _sal,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double _num(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.').trim()) ?? 0;

  static String _s(double v) =>
      v == 0 ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v');

  void _preencher(
    Nutrientes n, {
    required String base,
    double densidade = 1,
    List<String> alergenios = const [],
    List<String> tracos = const [],
  }) {
    _kcal.text = _s(n.kcal);
    _lip.text = _s(n.lipidos);
    _sat.text = _s(n.saturados);
    _hc.text = _s(n.hidratos);
    _ac.text = _s(n.acucares);
    _fib.text = _s(n.fibra);
    _prot.text = _s(n.proteina);
    _sal.text = _s(n.sal);
    _baseNutri = base;
    _densidade = densidade;
    _alerg
      ..clear()
      ..addAll(alergenios);
    _tracos
      ..clear()
      ..addAll(tracos);
  }

  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _daInsa() async {
    final r = await showInsaPicker(
      context,
      repo: ref.read(ingredientRepositoryProvider),
      termoInicial: _nome.text.trim(),
    );
    if (r == null || !mounted) return;
    setState(() {
      _preencher(r.nutri, base: '100g', alergenios: r.alergenios);
      _origemNutri = 'insa';
    });
    _aviso('Preenchido de "${r.nome}" (INSA). Confirma os valores.');
  }

  Future<void> _lerFoto() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      withData: true,
    );
    final f = (picked != null && picked.files.isNotEmpty)
        ? picked.files.first
        : null;
    if (f == null || f.bytes == null || !mounted) return;
    final bytes = f.bytes!.toList();
    setState(() => _lendo = true);
    try {
      final r = await ref
          .read(ingredientActionsProvider)
          .lerRotulo(bytes: bytes, nome: f.name);
      if (!mounted) return;
      setState(() {
        _preencher(
          r.nutri,
          base: r.base,
          densidade: r.densidade,
          alergenios: r.alergenios,
          tracos: r.tracos,
        );
        _origemNutri = 'rotulo';
        _foto = (nome: f.name, bytes: bytes);
      });
      _aviso('Rótulo lido. Confere os valores antes de adicionar.');
    } on Object catch (e) {
      _aviso('$e');
    } finally {
      if (mounted) setState(() => _lendo = false);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final nutri = NutriIngresso(
      nutri: Nutrientes(
        kcal: _num(_kcal),
        lipidos: _num(_lip),
        saturados: _num(_sat),
        hidratos: _num(_hc),
        acucares: _num(_ac),
        fibra: _num(_fib),
        proteina: _num(_prot),
        sal: _num(_sal),
      ),
      base: _baseNutri,
      densidade: _densidade,
      alergenios: _alerg.toList(),
      tracos: _tracos.toList(),
      origem: _origemNutri,
      foto: _foto,
    );
    final criar = widget.existente == null;
    Navigator.pop(
      context,
      IngredienteFormResultado(
        input: IngredienteInput(
          nome: _nome.text,
          caracteristica: _caracteristica.text,
          marca: _marca.text,
          nomeRotulo: _nomeRotulo.text,
          fornecedor: _fornecedor.text,
          preco: _num(_preco),
          gramasEmbalagem: _num(_gramas),
          disponivel: _disponivel,
          origem: _origem,
        ),
        nutri: criar && nutri.temDados ? nutri : null,
        abrirNutricao: criar && _abrirNutricao,
      ),
    );
  }

  Widget _campoNutri(String label, TextEditingController c) => TextFormField(
    controller: c,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label, isDense: true),
  );

  Widget _par(Widget a, Widget b) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Expanded(child: a),
        const SizedBox(width: 12),
        Expanded(child: b),
      ],
    ),
  );

  Widget _seccaoNutricao() => ExpansionTile(
    key: const ValueKey('nutri-opcional'),
    tilePadding: EdgeInsets.zero,
    childrenPadding: const EdgeInsets.only(bottom: 8),
    leading: const Icon(Icons.local_dining_outlined),
    title: const Text('Informação nutricional (opcional)'),
    subtitle: const Text('Valores por 100 g / 100 ml e alergénios'),
    children: [
      if (_lendo) const LinearProgressIndicator(),
      OutlinedButton.icon(
        onPressed: _lendo ? null : _daInsa,
        icon: const Icon(Icons.menu_book_outlined),
        label: const Text('Escolher da tabela INSA'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _lendo ? null : _lerFoto,
        icon: const Icon(Icons.photo_camera_outlined),
        label: Text(
          _foto == null
              ? 'Foto do rótulo (preencher com IA)'
              : 'Rótulo lido: ${_foto!.nome} — trocar foto',
        ),
      ),
      const SizedBox(height: 12),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: '100g', label: Text('por 100 g')),
          ButtonSegment(value: '100ml', label: Text('por 100 ml')),
        ],
        selected: {_baseNutri},
        onSelectionChanged: (s) => setState(() => _baseNutri = s.first),
      ),
      const SizedBox(height: 12),
      _par(
        _campoNutri('Energia (kcal)', _kcal),
        _campoNutri('Lípidos (g)', _lip),
      ),
      _par(
        _campoNutri('dos quais saturados (g)', _sat),
        _campoNutri('Hidratos de carbono (g)', _hc),
      ),
      _par(
        _campoNutri('dos quais açúcares (g)', _ac),
        _campoNutri('Fibra (g)', _fib),
      ),
      _par(_campoNutri('Proteína (g)', _prot), _campoNutri('Sal (g)', _sal)),
      const Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text('Contém (alergénios)'),
        ),
      ),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final a in kAlergenios)
            FilterChip(
              label: Text(a),
              selected: _alerg.contains(a),
              onSelected: (v) => setState(() {
                v ? _alerg.add(a) : _alerg.remove(a);
              }),
            ),
        ],
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text(
          'Abrir a folha completa depois (tabela INSA, foto do rótulo)',
        ),
        value: _abrirNutricao,
        onChanged: (v) => setState(() => _abrirNutricao = v ?? false),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final editar = widget.existente != null;
    final temProdutos =
        editar &&
        ref
            .watch(produtosDoIngredienteProvider(widget.existente!.id))
            .isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                editar ? 'Editar ingrediente' : 'Novo ingrediente',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nome,
                decoration: const InputDecoration(labelText: 'Nome *'),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _caracteristica,
                decoration: const InputDecoration(
                  labelText: 'Tipo / característica',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nomeRotulo,
                decoration: const InputDecoration(
                  labelText: 'Nome na etiqueta resumida (opcional)',
                  helperText:
                      'Curto e genérico, ex.: "Framboesa" em vez de '
                      '"Framboesa Congelada". Vazio = a app deduz.',
                  helperMaxLines: 2,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _marca,
                      decoration: const InputDecoration(labelText: 'Marca'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _fornecedor,
                      decoration: const InputDecoration(
                        labelText: 'Fornecedor',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (temProdutos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Custo atual: ${_n(widget.existente!.preco)} € por '
                    '${_n(widget.existente!.gramasEmbalagem)} g (compra mais '
                    'recente). Muda-se nos produtos de compra, em baixo.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _preco,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Preço da embalagem (€) *',
                        ),
                        validator: (v) =>
                            _num(_preco) <= 0 ? 'Indica o preço' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _gramas,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Gramas da embalagem *',
                        ),
                        validator: (v) =>
                            _num(_gramas) <= 0 ? 'Indica as gramas' : null,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              SegmentedButton<OrigemIngrediente>(
                segments: const [
                  ButtonSegment(
                    value: OrigemIngrediente.comprado,
                    label: Text('Comprado'),
                  ),
                  ButtonSegment(
                    value: OrigemIngrediente.fabricoProprio,
                    label: Text('Fabrico próprio'),
                  ),
                ],
                selected: {_origem},
                onSelectionChanged: (s) => setState(() => _origem = s.first),
              ),
              const SizedBox(height: 4),
              if (editar && _origem == OrigemIngrediente.comprado) ...[
                const SizedBox(height: 8),
                IngredientProductsSection(ingrediente: widget.existente!),
                const SizedBox(height: 8),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Disponível no fornecedor'),
                value: _disponivel,
                onChanged: (v) => setState(() => _disponivel = v),
              ),
              if (!editar) _seccaoNutricao(),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _submit,
                child: Text(editar ? 'Guardar' : 'Adicionar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
