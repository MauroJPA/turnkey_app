import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nutrition/nutrition.dart';
import '../application/ingredients_providers.dart';
import '../data/ingredient_repository.dart';
import '../domain/auto_insa.dart';
import '../domain/ingredient.dart';
import '../domain/ingrediente_referencia.dart';

/// Folha "Nutrição e alergénios" de um ingrediente.
Future<void> showNutricaoSheet(
  BuildContext context, {
  required Ingrediente ingrediente,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => _NutricaoSheet(ingrediente: ingrediente),
  );
}

class _NutricaoSheet extends ConsumerStatefulWidget {
  const _NutricaoSheet({required this.ingrediente});
  final Ingrediente ingrediente;

  @override
  ConsumerState<_NutricaoSheet> createState() => _NutricaoSheetState();
}

class _NutricaoSheetState extends ConsumerState<_NutricaoSheet> {
  final _kcal = TextEditingController();
  final _lip = TextEditingController();
  final _sat = TextEditingController();
  final _hc = TextEditingController();
  final _ac = TextEditingController();
  final _fib = TextEditingController();
  final _prot = TextEditingController();
  final _sal = TextEditingController();
  final _dens = TextEditingController();
  String _base = '100g';
  late Set<String> _alerg;
  late Set<String> _tracos;
  bool _busy = false;
  bool _irrelevante = false;
  String _origem = '';
  DateTime? _atualizado;
  late bool _temFoto;
  late String _fotoNome;

  /// Sugestões da INSA carregadas quando o ingrediente ainda não tem nutrição
  /// (ou ficou marcado para revisão).
  Future<ResumoAutoInsa>? _sugestoes;
  bool _sugestoesFechadas = false;

  @override
  void initState() {
    super.initState();
    final i = widget.ingrediente;
    _preencher(
      i.nutri,
      base: i.nutriBase,
      dens: i.nutriDensidade,
      al: i.alergenios,
      tr: i.alergeniosTracos,
    );
    _origem = i.nutriOrigem;
    _atualizado = i.nutriAtualizadoEm;
    _temFoto = i.temNutriFoto;
    _fotoNome = i.nutriFoto;
    _irrelevante = i.nutriIrrelevante;
    if (!i.temNutri || i.precisaRevisaoInsa) {
      _sugestoes =
          ref.read(ingredientActionsProvider).sugestoesInsa(i.id);
    }
  }

  void _aplicarCandidato(InsaCandidato c) {
    _preencher(c.nutri, base: '100g', al: c.alergenios, tr: const []);
    _origem = 'insa';
    _atualizado = DateTime.now();
    setState(() => _sugestoesFechadas = true);
    _snack('Preenchido de "${c.nome}" (INSA). Confirma.');
  }

  /// Aviso curto, dispensável ao tocar (não bloqueia o "Guardar" por baixo).
  void _snack(String texto, {Duration duration = const Duration(seconds: 3)}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 84),
        content: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: messenger.hideCurrentSnackBar,
          child: Text(texto),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final c in [
      _kcal, _lip, _sat, _hc, _ac, _fib, _prot, _sal, _dens,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _s(double v) =>
      v == 0 ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v');
  double _n(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.').trim()) ?? 0;

  void _preencher(
    Nutrientes n, {
    String? base,
    double? dens,
    List<String>? al,
    List<String>? tr,
  }) {
    _kcal.text = _s(n.kcal);
    _lip.text = _s(n.lipidos);
    _sat.text = _s(n.saturados);
    _hc.text = _s(n.hidratos);
    _ac.text = _s(n.acucares);
    _fib.text = _s(n.fibra);
    _prot.text = _s(n.proteina);
    _sal.text = _s(n.sal);
    _base = base == '100ml' ? '100ml' : '100g';
    _dens.text = (dens != null && dens > 0 && dens != 1) ? _s(dens) : '';
    _alerg = {...?al};
    _tracos = {...?tr};
    if (mounted) setState(() {});
  }

  Nutrientes get _atual => Nutrientes(
        kcal: _n(_kcal),
        lipidos: _n(_lip),
        saturados: _n(_sat),
        hidratos: _n(_hc),
        acucares: _n(_ac),
        fibra: _n(_fib),
        proteina: _n(_prot),
        sal: _n(_sal),
      );

  Future<void> _daInsa() async {
    final repo = ref.read(ingredientRepositoryProvider);
    final r = await showInsaPicker(
      context,
      repo: repo,
      termoInicial: widget.ingrediente.nome,
    );
    if (r == null) return;
    _preencher(r.nutri, base: '100g', al: r.alergenios, tr: const []);
    _origem = 'insa';
    _atualizado = DateTime.now();
    if (mounted) {
      setState(() => _sugestoesFechadas = true);
      _snack('Preenchido de "${r.nome}" (INSA). Confirma.');
    }
  }

  Future<void> _foto() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      withData: true,
    );
    final f = picked?.files.single;
    if (f?.bytes == null || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      duration: const Duration(seconds: 30),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 84),
      content: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: messenger.hideCurrentSnackBar,
        child: const Text('A ler o rótulo…'),
      ),
    ));
    try {
      final atualizado = await ref
          .read(ingredientActionsProvider)
          .analisarRotulo(
            widget.ingrediente.id,
            bytes: f!.bytes!.toList(),
            nome: f.name,
          );
      messenger.hideCurrentSnackBar();
      _preencher(
        atualizado.nutri,
        base: atualizado.nutriBase,
        dens: atualizado.nutriDensidade,
        al: atualizado.alergenios,
        tr: atualizado.alergeniosTracos,
      );
      _origem = 'rotulo';
      _atualizado = DateTime.now();
      _temFoto = atualizado.temNutriFoto;
      _fotoNome = atualizado.nutriFoto;
      if (mounted) {
        _snack('Rótulo lido. Confere os valores e guarda.');
      }
    } on Object catch (e) {
      messenger.hideCurrentSnackBar();
      if (mounted) _snack('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _anexarFoto() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      withData: true,
    );
    final f = picked?.files.single;
    if (f?.bytes == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final atualizado = await ref
          .read(ingredientActionsProvider)
          .anexarFotoNutri(
            widget.ingrediente.id,
            bytes: f!.bytes!.toList(),
            nome: f.name,
          );
      if (mounted) {
        setState(() {
          _temFoto = true;
          _fotoNome = atualizado.nutriFoto;
        });
        _snack('Foto da tabela nutricional anexada.');
      }
    } on Object catch (e) {
      if (mounted) _snack('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removerFoto() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(ingredientActionsProvider)
          .removerFotoNutri(widget.ingrediente.id);
      if (mounted) setState(() => _temFoto = false);
    } on Object catch (e) {
      if (mounted) _snack('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _fotoSeccao() {
    final url = _temFoto
        ? ref.read(ingredientRepositoryProvider).fotoNutriUrl(
              widget.ingrediente.id,
              _fotoNome,
              thumb: true,
            )
        : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Foto da tabela nutricional',
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        if (_temFoto)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.description_outlined),
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: _busy ? null : _anexarFoto,
                child: const Text('Substituir'),
              ),
              TextButton(
                onPressed: _busy ? null : _removerFoto,
                child: const Text('Remover'),
              ),
            ],
          )
        else
          OutlinedButton.icon(
            onPressed: _busy ? null : _anexarFoto,
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
            label: const Text('Anexar foto (sem IA)'),
          ),
      ],
    );
  }

  Future<void> _guardar() async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => _busy = true);
    try {
      await ref.read(ingredientActionsProvider).definirNutricao(
            widget.ingrediente.id,
            nutri: _atual,
            base: _base,
            densidade: _base == '100ml' ? (_n(_dens) > 0 ? _n(_dens) : 1) : 1,
            alergenios: _alerg.toList(),
            alergeniosTracos:
                _tracos.where((t) => !_alerg.contains(t)).toList(),
            origem: _origem == 'insa' || _origem == 'rotulo' ? _origem : 'manual',
            nutriIrrelevante: _irrelevante,
          );
      if (mounted) Navigator.pop(context);
    } on Object catch (e) {
      if (mounted) _snack('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _campo(
    String label,
    TextEditingController c,
    String suf, {
    bool enabled = true,
  }) => TextField(
        controller: c,
        enabled: enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          suffixText: suf,
          isDense: true,
        ),
      );

  Widget _chips(Set<String> sel, void Function(Set<String>) onCh) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final a in kAlergenios)
            FilterChip(
              label: Text(a),
              selected: sel.contains(a),
              onSelected: (v) {
                final n = {...sel};
                v ? n.add(a) : n.remove(a);
                onCh(n);
              },
            ),
        ],
      );

  Widget _sugestoesInsa() {
    return FutureBuilder<ResumoAutoInsa>(
      future: _sugestoes,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text('A procurar na tabela INSA…'),
              ],
            ),
          );
        }
        final r = snap.data?.resultados.isNotEmpty == true
            ? snap.data!.resultados.first
            : null;
        final cands = r?.candidatos ?? const <InsaCandidato>[];
        if (cands.isEmpty) {
          if (snap.hasError) return const SizedBox.shrink();
          return Card(
            margin: const EdgeInsets.only(top: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'A tabela INSA não tem nada parecido com este nome. '
                'Preenche à mão ou usa a foto do rótulo.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          );
        }
        return Card(
          margin: const EdgeInsets.only(top: 12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Parecidos na tabela INSA — escolhe o que corresponde',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Ignorar sugestões',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () =>
                          setState(() => _sugestoesFechadas = true),
                    ),
                  ],
                ),
                for (final c in cands.take(5))
                  InkWell(
                    onTap: _busy ? null : () => _aplicarCandidato(c),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.nome),
                                Text(
                                  [
                                    if (c.grupo.isNotEmpty) c.grupo,
                                    '${c.nutri.kcal.toStringAsFixed(0)} kcal',
                                    if (c.alergenios.isNotEmpty)
                                      'contém: ${c.alergenios.join(', ')}',
                                  ].join(' · '),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('≈ ${c.percentagem}%',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final origemTxt = switch (_origem) {
      'insa' => 'valores de referência (INSA)',
      'insa_revisao' => 'sugestão da INSA por confirmar',
      'rotulo' => 'lido do rótulo por IA',
      'openfoodfacts' => 'Open Food Facts',
      'manual' => 'introduzido à mão',
      _ => '',
    };
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nutrição e alergénios',
                style: Theme.of(context).textTheme.titleLarge),
            Text(widget.ingrediente.nome,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _daInsa,
                    icon: const Icon(Icons.menu_book_outlined, size: 18),
                    label: const Text('Tabela INSA'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _foto,
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: const Text('Foto do rótulo'),
                  ),
                ),
              ],
            ),
            if (_sugestoes != null && !_sugestoesFechadas) _sugestoesInsa(),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sem valor nutricional relevante'),
              subtitle: const Text(
                'Ex.: corante, aroma — usado em quantidade residual. '
                'Conta como zero confirmado, não como dados em falta.',
              ),
              value: _irrelevante,
              onChanged: (v) => setState(() => _irrelevante = v),
            ),
            const SizedBox(height: 4),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: '100g', label: Text('por 100 g')),
                ButtonSegment(value: '100ml', label: Text('por 100 ml')),
              ],
              selected: {_base},
              onSelectionChanged: _irrelevante
                  ? null
                  : (s) => setState(() => _base = s.first),
            ),
            if (_base == '100ml') ...[
              const SizedBox(height: 8),
              _campo(
                'Densidade (converte ml → g)',
                _dens,
                'g/ml',
                enabled: !_irrelevante,
              ),
            ],
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 8,
              childAspectRatio: 5.2,
              children: [
                _campo('Energia', _kcal, 'kcal', enabled: !_irrelevante),
                _campo('Lípidos', _lip, 'g', enabled: !_irrelevante),
                _campo('  dos quais saturados', _sat, 'g', enabled: !_irrelevante),
                _campo('Hidratos de carbono', _hc, 'g', enabled: !_irrelevante),
                _campo('  dos quais açúcares', _ac, 'g', enabled: !_irrelevante),
                _campo('Fibra', _fib, 'g', enabled: !_irrelevante),
                _campo('Proteínas', _prot, 'g', enabled: !_irrelevante),
                _campo('Sal', _sal, 'g', enabled: !_irrelevante),
              ],
            ),
            const SizedBox(height: 12),
            Text('Contém', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            _chips(_alerg, (n) => setState(() => _alerg = n)),
            const SizedBox(height: 10),
            Text('Pode conter (vestígios)',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            _chips(_tracos, (n) => setState(() => _tracos = n)),
            const SizedBox(height: 14),
            _fotoSeccao(),
            if (origemTxt.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Origem: $origemTxt'
                '${_atualizado != null ? ' · ${_atualizado!.day.toString().padLeft(2, '0')}/${_atualizado!.month.toString().padLeft(2, '0')}/${_atualizado!.year}' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _guardar,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Folha para escolher um alimento da tabela INSA (pesquisa por nome).
Future<IngredienteReferencia?> showInsaPicker(
  BuildContext context, {
  required IngredientRepository repo,
  String termoInicial = '',
}) {
  return showModalBottomSheet<IngredienteReferencia>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _InsaPicker(repo: repo, termoInicial: termoInicial),
  );
}

class _InsaPicker extends StatefulWidget {
  const _InsaPicker({required this.repo, required this.termoInicial});
  final IngredientRepository repo;
  final String termoInicial;

  @override
  State<_InsaPicker> createState() => _InsaPickerState();
}

class _InsaPickerState extends State<_InsaPicker> {
  late final _q = TextEditingController(text: widget.termoInicial);
  Future<List<IngredienteReferencia>>? _fut;

  @override
  void initState() {
    super.initState();
    _buscar();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _buscar() {
    final f = widget.repo.referencias(q: _q.text.trim());
    setState(() {
      _fut = f;
    });
  }

  static String _norm(String s) {
    const m = {
      'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a', 'é': 'e', 'ê': 'e', 'í': 'i',
      'ó': 'o', 'õ': 'o', 'ô': 'o', 'ú': 'u', 'ç': 'c',
    };
    var o = s.toLowerCase();
    m.forEach((k, v) => o = o.replaceAll(k, v));
    return o;
  }

  static Set<String> _toks(String s) => _norm(s)
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .split(RegExp(r'\s+'))
      .where((t) => t.length > 2)
      .toSet();

  /// Ordena as referências pela semelhança do nome com [termoInicial].
  List<IngredienteReferencia> _ordenar(List<IngredienteReferencia> l) {
    final alvo = _toks(widget.termoInicial);
    if (alvo.isEmpty) return l;
    double score(IngredienteReferencia r) {
      final b = _toks(r.nome);
      if (b.isEmpty) return 0;
      return alvo.intersection(b).length / alvo.union(b).length;
    }

    final copia = [...l]..sort((a, b) => score(b).compareTo(score(a)));
    return copia;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Text('Tabela INSA',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _q,
              autofocus: true,
              onSubmitted: (_) => _buscar(),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Procurar alimento',
                isDense: true,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _buscar,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<IngredienteReferencia>>(
                future: _fut,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text('${snap.error}'));
                  }
                  final itens = _ordenar(snap.data ?? const []);
                  if (itens.isEmpty) {
                    return const Center(
                      child: Text(
                        'Nada encontrado. A tabela INSA pode ainda não '
                        'estar importada no servidor.',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: itens.length,
                    itemBuilder: (_, i) {
                      final r = itens[i];
                      return ListTile(
                        dense: true,
                        title: Text(r.nome),
                        subtitle: Text([
                          if (r.grupo.isNotEmpty) r.grupo,
                          '${r.nutri.kcal.toStringAsFixed(0)} kcal/100 g',
                        ].join(' · ')),
                        onTap: () => Navigator.pop(context, r),
                      );
                    },
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
