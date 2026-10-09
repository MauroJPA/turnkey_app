import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/printing/print_etiquetas.dart';
import '../../../core/printing/qr_svg.dart';
import '../../tech_sheets/domain/tech_sheet.dart';
import '../application/etiqueta_prefs_providers.dart';
import '../application/produtor_providers.dart';
import '../application/produtos_providers.dart';
import '../domain/etiqueta.dart';

Future<void> showEtiquetaSheet(
  BuildContext context, {
  required FichaTecnica ficha,

  /// Etiqueta de um lote de produção: o código (e o QR para a sua página),
  /// a data de fabrico do lote.
  String? loteCodigo,
  String? loteUrl,
  DateTime? loteFabrico,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => _Sheet(
      ficha: ficha,
      loteCodigo: loteCodigo,
      loteUrl: loteUrl,
      loteFabrico: loteFabrico,
    ),
  );
}

class _Sheet extends ConsumerStatefulWidget {
  const _Sheet({
    required this.ficha,
    this.loteCodigo,
    this.loteUrl,
    this.loteFabrico,
  });
  final FichaTecnica ficha;
  final String? loteCodigo;
  final String? loteUrl;
  final DateTime? loteFabrico;

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
  bool _mostrarSubnome = false;
  TamanhoEtiqueta _tamanho = tamanhosEtiqueta.first;

  /// Folha maior onde se juntam várias etiquetas para recortar (`null` = uma
  /// etiqueta por página).
  TamanhoEtiqueta? _folha;
  bool _linhasDeCorte = true;
  int _frente = frenteMinMm;
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
    if (widget.loteCodigo != null) _lote.text = widget.loteCodigo!;
    if (widget.loteFabrico != null) {
      final d = widget.loteFabrico!;
      _fabrico = DateTime(d.year, d.month, d.day);
    }
  }

  @override
  void dispose() {
    _copias.dispose();
    _lote.dispose();
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
      subnome: _mostrarSubnome ? f.subnome : '',
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
      qrSvg: widget.loteUrl != null && _lote.text.trim() == widget.loteCodigo
          ? qrSvg(widget.loteUrl!)
          : '',
      produtor: _produtor.text,
      copias: (int.tryParse(_copias.text.trim()) ?? 1).clamp(1, 500),
      larguraMm: _tamanho.larguraMm,
      alturaTotalMm: _tamanho.alturaMm,
      alturaFrenteMm: _frente,
      folha: _folha,
      linhasDeCorte: _linhasDeCorte,
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

  /// Menor tamanho padrão onde cabem [frente] mm de frente e [corpo] mm de
  /// parte de baixo (`null` se nenhum chega).
  TamanhoEtiqueta? _menorTamanhoQueCabe(int frente, int corpo) {
    for (final t in tamanhosEtiqueta) {
      if (t.alturaMm - frente >= corpo) return t;
    }
    return null;
  }

  /// "Várias etiquetas numa folha": junta etiquetas pequenas numa folha maior
  /// (p. ex. 3 de 50 × 100 numa de 150 × 100) para recortar depois.
  Widget _blocoFolha(EtiquetaDados dados) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final ativo = _folha != null;
    final disp = dados.disposicao;
    final total = dados.copias;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: ativo,
              onChanged: (v) => setState(() {
                _folha = v ? (_folha ?? tamanhosFolha.first) : null;
                // ao ligar, propõe encher uma folha (se ainda estava em 1)
                if (v && (int.tryParse(_copias.text.trim()) ?? 1) == 1) {
                  final n = disposicaoFolha(_folha!, _tamanho).porFolha;
                  if (n > 1) _copias.text = '$n';
                }
              }),
              title: const Text('Várias etiquetas numa folha maior'),
              subtitle: const Text(
                'Para recortar depois: p. ex. 3 etiquetas de 50 × 100 mm numa '
                'folha de 150 × 100 mm.',
              ),
            ),
            if (ativo) ...[
              DropdownButtonFormField<TamanhoEtiqueta>(
                key: ValueKey('folha-${_folha!.label}'),
                initialValue: _folha,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Tamanho da folha (a que se põe na impressora)',
                ),
                items: [
                  for (final t in tamanhosFolha)
                    DropdownMenuItem(value: t, child: Text(t.label)),
                ],
                onChanged: (v) => setState(() => _folha = v ?? _folha),
              ),
              const SizedBox(height: 8),
              if (disp.porFolha < 1)
                Text(
                  'A etiqueta de ${_tamanho.label} não cabe numa folha de '
                  '${_folha!.label}. Escolhe uma etiqueta mais pequena ou '
                  'outra folha.',
                  style: tt.bodyMedium?.copyWith(color: cs.error),
                )
              else if (disp.porFolha == 1)
                Text(
                  'Só cabe 1 etiqueta de ${_tamanho.label} numa folha de '
                  '${_folha!.label} — sai uma por folha.',
                  style: tt.bodyMedium,
                )
              else
                Text(
                  'Cabem ${disp.porFolha} etiquetas de ${_tamanho.label} em '
                  'cada folha de ${_folha!.label} '
                  '(${disp.colunas} × ${disp.linhas}). '
                  '$total etiqueta${total == 1 ? '' : 's'} = '
                  '${dados.paginas} folha${dados.paginas == 1 ? '' : 's'}.',
                  style: tt.bodyMedium,
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _linhasDeCorte,
                onChanged: (v) => setState(() => _linhasDeCorte = v),
                title: const Text('Linhas de corte'),
                subtitle: const Text(
                  'Tracejado fino entre as etiquetas, para recortares.',
                ),
              ),
            ],
          ],
        ),
      ),
    );
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
      _mostrarSubnome = p.mostrarSubnome && widget.ficha.subnome.isNotEmpty;
      _tamanho = p.tamanho;
      _frente = p.alturaFrenteMm;
      _folha = p.folha;
      _linhasDeCorte = p.linhasDeCorte;
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
    final frenteCurta =
        medidas != null && medidas.frenteMm > dados.alturaFrenteMm + 0.5;
    final corpoCurto =
        medidas != null && medidas.corpoMm > dados.alturaCorpoMm + 0.5;
    final curto = frenteCurta || corpoCurto;
    // Frente mínima que serve (15–25) e o menor tamanho padrão onde tudo cabe.
    final frenteNecessaria = medidas == null
        ? dados.alturaFrenteMm
        : medidas.frenteMm.ceil().clamp(frenteMinMm, frenteMaxMm);
    final frenteExcede =
        medidas != null && medidas.frenteMm.ceil() > frenteMaxMm;
    final tamanhoSugerido = medidas == null
        ? null
        : _menorTamanhoQueCabe(frenteNecessaria, medidas.corpoMm.ceil());

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
            'A frente (nome, subnome, característica e peso) fica à vista, com '
            '$frenteMinMm a $frenteMaxMm mm; o resto, depois da dobra, leva a '
            'informação legal. Tamanho preferido: 50 × 80 mm.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _mostrarSubnome && widget.ficha.subnome.isNotEmpty,
            onChanged: widget.ficha.subnome.isEmpty
                ? null
                : (v) => setState(() => _mostrarSubnome = v),
            title: const Text('Imprimir o subnome'),
            subtitle: Text(
              widget.ficha.subnome.isEmpty
                  ? 'Esta ficha não tem subnome — define-o em Editar ficha.'
                  : 'Aparece por baixo do nome: ${widget.ficha.subnome}.',
            ),
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
            decoration: InputDecoration(
              labelText: 'Número de etiquetas',
              helperText: _folha == null
                  ? null
                  : 'No total, contando todas as que vão nas folhas.',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<TamanhoEtiqueta>(
            key: ValueKey('tamanho-${_tamanho.label}'),
            initialValue: _tamanho,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Tamanho da etiqueta (térmica)',
              helperText: 'Medidas padrão do mercado. Preferido: 50 × 80 mm.',
            ),
            items: [
              for (final t in tamanhosEtiqueta)
                DropdownMenuItem(value: t, child: Text(t.label)),
            ],
            onChanged: (v) => setState(() => _tamanho = v ?? _tamanho),
          ),
          const SizedBox(height: 8),
          Text(
            'Frente: $_frente mm · parte de baixo: '
            '${_tamanho.alturaMm - _frente} mm',
          ),
          Slider(
            value: _frente.toDouble(),
            min: frenteMinMm.toDouble(),
            max: frenteMaxMm.toDouble(),
            divisions: frenteMaxMm - frenteMinMm,
            label: '$_frente mm',
            onChanged: (v) => setState(() => _frente = v.round()),
          ),
          Card(
            color: curto ? cs.errorContainer : cs.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medidas == null
                        ? 'A calcular o espaço necessário…'
                        : 'Com estes dados é preciso: frente '
                              '${medidas.frenteMm.ceil()} mm + parte de baixo '
                              '${medidas.corpoMm.ceil()} mm.',
                    style: TextStyle(color: curto ? cs.onErrorContainer : null),
                  ),
                  if (frenteExcede)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'O nome, subnome e característica não cabem nos '
                        '$frenteMaxMm mm máximos da frente — encurta a '
                        'característica ou desliga o subnome.',
                        style: TextStyle(color: cs.onErrorContainer),
                      ),
                    )
                  else if (frenteCurta)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'A frente de $_frente mm corta o texto: precisa de '
                        '$frenteNecessaria mm.',
                        style: TextStyle(color: cs.onErrorContainer),
                      ),
                    ),
                  if (corpoCurto && !frenteExcede)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        tamanhoSugerido == null
                            ? 'A informação legal não cabe em nenhum tamanho '
                                  'disponível — usa a lista resumida ou a '
                                  'nutrição linear.'
                            : 'A informação não cabe em ${_tamanho.label}.',
                        style: TextStyle(color: cs.onErrorContainer),
                      ),
                    ),
                  if (medidas != null && !frenteExcede)
                    Wrap(
                      spacing: 8,
                      children: [
                        if (frenteCurta)
                          TextButton(
                            onPressed: () =>
                                setState(() => _frente = frenteNecessaria),
                            child: Text('Frente de $frenteNecessaria mm'),
                          ),
                        if (corpoCurto && tamanhoSugerido != null)
                          TextButton(
                            onPressed: () => setState(() {
                              _tamanho = tamanhoSugerido;
                              if (frenteCurta) _frente = frenteNecessaria;
                            }),
                            child: Text('Usar ${tamanhoSugerido.label}'),
                          ),
                      ],
                    ),
                  Text(
                    'Letra de 6 pt (já perto do mínimo legal, por isso não se '
                    'reduz). Prefere-se sempre o tamanho mais pequeno onde '
                    'tudo cabe.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _blocoFolha(dados),
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
                  mostrarSubnome: _mostrarSubnome,
                  larguraMm: d.larguraMm,
                  alturaTotalMm: d.alturaTotalMm,
                  alturaFrenteMm: d.alturaFrenteMm,
                  folha: d.folha,
                  linhasDeCorte: d.linhasDeCorte,
                ),
              );
              abrirPaginaEtiquetas(etiquetaPagina(d));
            },
            icon: const Icon(Icons.print_outlined),
            label: Text(
              dados.emFolha
                  ? 'Pré-visualizar e imprimir (${dados.paginas} '
                        'folha${dados.paginas == 1 ? '' : 's'})'
                  : 'Pré-visualizar e imprimir',
            ),
          ),
        ],
      ),
    );
  }
}
