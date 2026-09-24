import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/printing/print_etiquetas.dart';
import '../../tech_sheets/domain/tech_sheet.dart';
import '../application/produtor_providers.dart';
import '../application/produtos_providers.dart';
import '../domain/etiqueta.dart';

Future<void> showEtiquetaSheet(
  BuildContext context, {
  required FichaTecnica ficha,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => _Sheet(ficha: ficha),
  );
}

class _Sheet extends ConsumerStatefulWidget {
  const _Sheet({required this.ficha});
  final FichaTecnica ficha;

  @override
  ConsumerState<_Sheet> createState() => _SheetState();
}

class _SheetState extends ConsumerState<_Sheet> {
  bool _resumida = false;
  EtiquetaNutri _modoNutri = EtiquetaNutri.tabela;
  EtiquetaData _tipoData = EtiquetaData.preferencia;
  DateTime _fabrico = () {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }();
  bool _mostrarE = false;
  final _copias = TextEditingController(text: '1');
  final _lote = TextEditingController();
  final _altura = TextEditingController(text: '55');
  final _produtor = TextEditingController();
  bool _loteTocado = false;
  bool _produtorCarregado = false;
  bool _aGuardar = false;

  @override
  void initState() {
    super.initState();
    _lote.text = _loteAuto(_fabrico);
  }

  @override
  void dispose() {
    _copias.dispose();
    _lote.dispose();
    _altura.dispose();
    _produtor.dispose();
    super.dispose();
  }

  static String _loteAuto(DateTime d) =>
      '${(d.year % 100).toString().padLeft(2, '0')}'
      '${d.month.toString().padLeft(2, '0')}'
      '${d.day.toString().padLeft(2, '0')}';

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _escolherData() async {
    final hoje = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _fabrico,
      firstDate: DateTime(hoje.year - 1),
      lastDate: DateTime(hoje.year + 1),
    );
    if (d == null) return;
    setState(() {
      _fabrico = d;
      if (!_loteTocado) _lote.text = _loteAuto(d);
    });
  }

  Future<void> _guardarProdutor() async {
    setState(() => _aGuardar = true);
    try {
      await guardarProdutorRotulo(ref, _produtor.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Produtor guardado para as próximas etiquetas.'),
        ),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível guardar (só o proprietário pode).'),
        ),
      );
    } finally {
      if (mounted) setState(() => _aGuardar = false);
    }
  }

  EtiquetaDados _dados() {
    final f = widget.ficha;
    final n = f.nutri;
    return EtiquetaDados(
      nome: f.nome,
      descricao: f.descricao,
      ingredientes: ref.read(produtoIngredientesProvider(f.id)).valueOrNull,
      resumida: _resumida,
      nutri: n.vazio ? null : n.por100g,
      modoNutri: _modoNutri,
      tracos: n.alergeniosTracos,
      pesoLiquidoG: n.pesoUnidadeG,
      mostrarE: _mostrarE,
      conservacao: f.conservacao,
      fabrico: _fabrico,
      validadeDias: f.validadeDias,
      tipoData: _tipoData,
      lote: _lote.text,
      produtor: _produtor.text,
      copias: (int.tryParse(_copias.text.trim()) ?? 1).clamp(1, 500),
      alturaCorpoMm: (int.tryParse(_altura.text.trim()) ?? 55).clamp(30, 120),
    );
  }

  @override
  Widget build(BuildContext context) {
    final produtorGuardado = ref.watch(produtorRotuloProvider);
    ref.watch(produtoIngredientesProvider(widget.ficha.id));
    if (!_produtorCarregado && produtorGuardado.hasValue) {
      _produtorCarregado = true;
      _produtor.text = produtorGuardado.value ?? '';
    }
    final ehOwner = ref.watch(currentPapelProvider).isOwner;
    final cs = Theme.of(context).colorScheme;
    final avisos = avisosEtiqueta(_dados());

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text(
            'Etiqueta — ${widget.ficha.nome}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            '50 mm de largura: 25 mm de frente (nome, descrição e peso) e o '
            'resto depois da dobra (informação legal).',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (avisos.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              color: cs.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final a in avisos)
                      Text(
                        '• $a',
                        style: TextStyle(color: cs.onErrorContainer),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text('Lista de ingredientes'),
          const SizedBox(height: 6),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Completa')),
              ButtonSegment(value: true, label: Text('Resumida')),
            ],
            selected: {_resumida},
            onSelectionChanged: (s) => setState(() => _resumida = s.first),
          ),
          const SizedBox(height: 16),
          const Text('Declaração nutricional'),
          const SizedBox(height: 6),
          SegmentedButton<EtiquetaNutri>(
            showSelectedIcon: false,
            segments: [
              for (final m in EtiquetaNutri.values)
                ButtonSegment(value: m, label: Text(m.label)),
            ],
            selected: {_modoNutri},
            onSelectionChanged: (s) => setState(() => _modoNutri = s.first),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _escolherData,
            icon: const Icon(Icons.event_outlined),
            label: Text('Data de fabrico: ${_fmt(_fabrico)}'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<EtiquetaData>(
            initialValue: _tipoData,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Expressão da data',
              helperText: widget.ficha.validadeDias > 0
                  ? 'Validade: ${widget.ficha.validadeDias} dias após o fabrico'
                  : 'Define a validade na ficha',
            ),
            items: [
              for (final t in EtiquetaData.values)
                DropdownMenuItem(value: t, child: Text(t.texto)),
            ],
            onChanged: (v) => setState(() => _tipoData = v ?? _tipoData),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _lote,
            onChanged: (_) => setState(() => _loteTocado = true),
            decoration: const InputDecoration(
              labelText: 'Lote (vazio = não imprime)',
              helperText: 'Por omissão, a data de fabrico (aammdd).',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _copias,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Número de etiquetas'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _altura,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Altura da parte de baixo (mm)',
              helperText:
                  'A frente tem 25 mm. Se a informação não couber em 55 mm, '
                  'aumenta (ex.: 75).',
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _mostrarE,
            onChanged: (v) => setState(() => _mostrarE = v),
            title: const Text('Símbolo ℮ junto ao peso'),
            subtitle: const Text(
              'Só se pesarem as embalagens: garante que a média do lote não '
              'fica abaixo do peso indicado.',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _produtor,
            minLines: 2,
            maxLines: 4,
            maxLength: 300,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Produtor (nome e morada)',
              helperText:
                  'Obrigatório na etiqueta. Ex.: Gookie Cookies, Lda — Rua …',
            ),
          ),
          if (ehOwner)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _aGuardar ? null : _guardarProdutor,
                child: const Text('Guardar como predefinição da empresa'),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Antes de vender, confirma com a ASAE/DGAV que a etiqueta cumpre a '
            'lei (ver docs/ROTULAGEM_LEGAL.md). Imprime a lista completa '
            'enquanto não houver confirmação para a resumida.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => abrirPaginaEtiquetas(etiquetaPagina(_dados())),
            icon: const Icon(Icons.print_outlined),
            label: const Text('Pré-visualizar e imprimir'),
          ),
        ],
      ),
    );
  }
}
