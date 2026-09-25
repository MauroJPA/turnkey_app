import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/printing/print_etiquetas.dart';
import '../../tech_sheets/domain/tech_sheet.dart';
import '../application/etiqueta_prefs_providers.dart';
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
  bool _imprimirDatas = true;
  final _copias = TextEditingController(text: '1');
  final _lote = TextEditingController();
  final _largura = TextEditingController(text: '50');
  final _frente = TextEditingController(text: '25');
  final _altura = TextEditingController(text: '55');
  MedidasEtiqueta? _medidas;
  String _htmlMedido = '';
  Timer? _debounce;
  final _produtor = TextEditingController();
  bool _produtorCarregado = false;
  bool _prefsCarregadas = false;
  bool _aGuardar = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _copias.dispose();
    _lote.dispose();
    _largura.dispose();
    _frente.dispose();
    _altura.dispose();
    _debounce?.cancel();
    _produtor.dispose();
    super.dispose();
  }

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
      imprimirDatas: _imprimirDatas,
      validadeDias: f.validadeDias,
      tipoData: _tipoData,
      lote: _lote.text,
      produtor: _produtor.text,
      copias: (int.tryParse(_copias.text.trim()) ?? 1).clamp(1, 500),
      larguraMm: (int.tryParse(_largura.text.trim()) ?? 50).clamp(30, 120),
      alturaFrenteMm: (int.tryParse(_frente.text.trim()) ?? 25).clamp(15, 80),
      alturaCorpoMm: (int.tryParse(_altura.text.trim()) ?? 55).clamp(30, 150),
    );
  }

  void _agendarMedicao(String html) {
    if (html == _htmlMedido) return;
    _htmlMedido = html;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final m = await medirEtiqueta(
        (t) => etiquetaPagina(_dados(), tokenMedicao: t),
      );
      if (mounted && _htmlMedido == html) setState(() => _medidas = m);
    });
  }

  void _usarMinimo(MedidasEtiqueta m) {
    setState(() {
      _frente.text = '${m.frenteMm.ceil()}';
      _altura.text = '${m.corpoMm.ceil()}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final produtorGuardado = ref.watch(produtorRotuloProvider);
    ref.watch(produtoIngredientesProvider(widget.ficha.id));
    final prefsGuardadas = ref.watch(etiquetaPrefsProvider(widget.ficha.id));
    if (!_prefsCarregadas && prefsGuardadas.hasValue) {
      _prefsCarregadas = true;
      final p = prefsGuardadas.requireValue;
      _resumida = p.resumida;
      _modoNutri = p.modoNutri;
      _tipoData = p.tipoData;
      _imprimirDatas = p.imprimirDatas;
      _mostrarE = p.mostrarE;
      _largura.text = '${p.larguraMm}';
      _frente.text = '${p.alturaFrenteMm}';
      _altura.text = '${p.alturaCorpoMm}';
    }
    if (!_produtorCarregado && produtorGuardado.hasValue) {
      _produtorCarregado = true;
      _produtor.text = produtorGuardado.value ?? '';
    }
    final ehOwner = ref.watch(currentPapelProvider).isOwner;
    final cs = Theme.of(context).colorScheme;
    final dados = _dados();
    final avisos = avisosEtiqueta(dados);
    _agendarMedicao(etiquetaPagina(dados));
    final medidas = _medidas;
    final curto =
        medidas != null &&
        (medidas.frenteMm > dados.alturaFrenteMm + 0.5 ||
            medidas.corpoMm > dados.alturaCorpoMm + 0.5);

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
            'A frente (nome, descrição e peso) fica à vista; o resto, depois da '
            'dobra, leva a informação legal. Tamanho por omissão: 50 × 80 mm '
            '(25 + 55).',
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _imprimirDatas,
            onChanged: (v) => setState(() => _imprimirDatas = v),
            title: const Text('Imprimir as datas'),
            subtitle: const Text(
              'Desligado: ficam em branco para escrever à caneta, e a etiqueta '
              'diz "Validade: X dias após a data de fabrico".',
            ),
          ),
          OutlinedButton.icon(
            onPressed: _imprimirDatas ? _escolherData : null,
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
            onChanged: _imprimirDatas
                ? (v) => setState(() => _tipoData = v ?? _tipoData)
                : null,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _lote,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Lote (vazio = não imprime)',
              helperText:
                  'Opcional. Sem controlo de lotes, deixa em branco (a confirmar com a ASAE).',
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (c, l) in [
                (_largura, 'Largura (mm)'),
                (_frente, 'Frente (mm)'),
                (_altura, 'Parte de baixo (mm)'),
              ]) ...[
                Expanded(
                  child: TextField(
                    controller: c,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(labelText: l),
                  ),
                ),
                if (c != _altura) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Card(
            color: curto ? cs.errorContainer : cs.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medidas == null
                        ? 'A calcular o tamanho mínimo…'
                        : 'Mínimo recomendado com estes dados e '
                              '${dados.larguraMm} mm de largura: frente '
                              '${medidas.frenteMm.ceil()} mm + parte de baixo '
                              '${medidas.corpoMm.ceil()} mm '
                              '(${dados.larguraMm} × '
                              '${medidas.frenteMm.ceil() + medidas.corpoMm.ceil()} mm).',
                    style: TextStyle(color: curto ? cs.onErrorContainer : null),
                  ),
                  if (curto)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Com o tamanho escolhido, parte do texto fica cortada.',
                        style: TextStyle(color: cs.onErrorContainer),
                      ),
                    ),
                  if (medidas != null)
                    TextButton(
                      onPressed: () => _usarMinimo(medidas),
                      child: const Text('Usar o mínimo'),
                    ),
                  Text(
                    'Letra de 6 pt (já perto do mínimo legal, por isso não se '
                    'reduz). Uma etiqueta mais estreita precisa de mais altura.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
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
                  'Obrigatório na etiqueta. Ex.: A Minha Empresa, Lda — Rua …',
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
            onPressed: () {
              final d = _dados();
              guardarEtiquetaPrefs(
                ref,
                widget.ficha.id,
                EtiquetaPrefs(
                  resumida: d.resumida,
                  modoNutri: d.modoNutri,
                  tipoData: d.tipoData,
                  imprimirDatas: d.imprimirDatas,
                  mostrarE: d.mostrarE,
                  larguraMm: d.larguraMm,
                  alturaFrenteMm: d.alturaFrenteMm,
                  alturaCorpoMm: d.alturaCorpoMm,
                ),
              );
              abrirPaginaEtiquetas(etiquetaPagina(d));
            },
            icon: const Icon(Icons.print_outlined),
            label: const Text('Pré-visualizar e imprimir'),
          ),
        ],
      ),
    );
  }
}
