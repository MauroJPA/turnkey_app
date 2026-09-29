import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/data/marcas_fornecedores_providers.dart';
import '../../../core/widgets/autocomplete_text_field.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../application/consumivel_providers.dart';
import '../domain/consumivel.dart';
import 'consumiveis_screen.dart' show apresentaEstadoFds;

Future<void> abrirConsumivelSheet(
  BuildContext context, {
  Consumivel? existente,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => ConsumivelSheet(existente: existente),
);

/// Documento escolhido antes de o produto estar guardado: envia-se ao guardar.
class DocumentoPendente {
  const DocumentoPendente({
    required this.tipo,
    required this.ficheiro,
    this.titulo = '',
    this.versao = '',
    this.data,
  });

  final TipoDocumento tipo;
  final PlatformFile ficheiro;
  final String titulo;
  final String versao;
  final DateTime? data;

  String get nomeVisivel => titulo.isNotEmpty ? titulo : ficheiro.name;
}

String _dataCurta(DateTime? d) => d == null
    ? 'sem data'
    : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class ConsumivelSheet extends ConsumerStatefulWidget {
  const ConsumivelSheet({super.key, this.existente});

  final Consumivel? existente;

  @override
  ConsumerState<ConsumivelSheet> createState() => _ConsumivelSheetState();
}

class _ConsumivelSheetState extends ConsumerState<ConsumivelSheet> {
  late Consumivel? _atual = widget.existente;
  late final _nome = TextEditingController(text: _atual?.nome ?? '');
  late final _caracteristica = TextEditingController(
    text: _atual?.caracteristica ?? '',
  );
  late final _marca = TextEditingController(text: _atual?.marca ?? '');
  late final _fornecedor = TextEditingController(
    text: _atual?.fornecedor ?? '',
  );
  late final _embalagem = TextEditingController(text: _atual?.embalagem ?? '');
  late final _preco = TextEditingController(
    text: (_atual?.preco ?? 0) > 0 ? '${_atual!.preco}' : '',
  );
  late final _precoVenda = TextEditingController(
    text: (_atual?.precoVenda ?? 0) > 0 ? '${_atual!.precoVenda}' : '',
  );
  late final _notas = TextEditingController(text: _atual?.notas ?? '');
  late final _categoria = TextEditingController(
    text: _atual?.categoria ?? 'Limpeza',
  );
  late bool _exigeFds = _atual?.exigeFds ?? true;
  bool _busy = false;
  String? _erro;
  final List<DocumentoPendente> _pendentes = [];

  bool get _podeEditar => ref.read(currentPapelProvider).canEditBusiness;

  @override
  void dispose() {
    for (final c in [
      _nome,
      _caracteristica,
      _marca,
      _fornecedor,
      _embalagem,
      _preco,
      _precoVenda,
      _notas,
      _categoria,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double get _precoV =>
      double.tryParse(_preco.text.replaceAll(',', '.').trim()) ?? 0;
  double get _precoVendaV =>
      double.tryParse(_precoVenda.text.replaceAll(',', '.').trim()) ?? 0;

  Future<void> _guardar() async {
    if (_nome.text.trim().isEmpty) {
      setState(() => _erro = 'Indica o nome do produto.');
      return;
    }
    setState(() {
      _busy = true;
      _erro = null;
    });
    try {
      final input = ConsumivelInput(
        nome: _nome.text,
        categoria: _categoria.text,
        caracteristica: _caracteristica.text,
        marca: _marca.text,
        fornecedor: _fornecedor.text,
        embalagem: _embalagem.text,
        preco: _precoV,
        precoVenda: _precoVendaV,
        exigeFds: _exigeFds,
        notas: _notas.text,
      );
      final a = ref.read(consumivelActionsProvider);
      if (_atual == null) {
        _atual = await a.criar(input);
      } else {
        final id = _atual!.id;
        await a.atualizar(id, input, precoMudou: _precoV != _atual!.preco);
        final lista = await ref.read(consumiveisListProvider.future);
        _atual = lista.where((c) => c.id == id).firstOrNull ?? _atual;
      }
      // documentos escolhidos antes de guardar: envia os que conseguir; os que
      // falharem ficam na lista para tentar de novo (o produto já está guardado)
      final falharam = <DocumentoPendente>[];
      for (final d in _pendentes) {
        try {
          await a.anexar(
            consumivelId: _atual!.id,
            tipo: d.tipo,
            bytes: d.ficheiro.bytes!,
            nomeFicheiro: d.ficheiro.name,
            titulo: d.titulo,
            versao: d.versao,
            dataDocumento: d.data,
          );
        } on Object {
          falharam.add(d);
        }
      }
      final enviados = _pendentes.length - falharam.length;
      _pendentes
        ..clear()
        ..addAll(falharam);
      if (falharam.isNotEmpty) {
        _erro =
            'O produto ficou guardado, mas ${falharam.length} documento(s) '
            'não seguiram. Carrega em Guardar para tentar de novo.';
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enviados > 0
                  ? 'Guardado, com $enviados documento(s) anexado(s).'
                  : 'Guardado.',
            ),
          ),
        );
      }
    } on Object {
      _erro = 'Não foi possível guardar. Tenta de novo.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apagar() async {
    final c = _atual;
    if (c == null) return;
    final ok = await confirmDialog(
      context,
      titulo: 'Apagar produto?',
      mensagem:
          'Remove "${c.nome}" da lista. Os documentos anexados também deixam '
          'de aparecer.',
      confirmar: 'Apagar',
      destrutivo: true,
    );
    if (!ok) return;
    await ref.read(consumivelActionsProvider).apagar(c.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _anexarPendente() async {
    final d = await showDialog<DocumentoPendente>(
      context: context,
      builder: (_) => const _AnexarDialog(),
    );
    if (d != null) setState(() => _pendentes.add(d));
  }

  /// Documentos ainda por enviar (escolhidos antes de guardar o produto).
  Widget _blocoPendentes(TextTheme tt) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        _atual == null
            ? 'Documentos (${_pendentes.length})'
            : 'Por enviar (${_pendentes.length})',
        style: tt.titleSmall,
      ),
      const SizedBox(height: 4),
      if (_atual == null)
        Text(
          'Podes escolher já a ficha de dados de segurança: segue quando '
          'guardares o produto.',
          style: tt.bodySmall,
        ),
      for (final d in _pendentes)
        Card(
          margin: const EdgeInsets.only(top: 6),
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.attach_file),
            title: Text(d.nomeVisivel),
            subtitle: Text(
              [
                d.tipo.label,
                if (d.versao.isNotEmpty) 'v. ${d.versao}',
                if (d.data != null) _dataCurta(d.data),
              ].join(' · '),
            ),
            trailing: IconButton(
              tooltip: 'Tirar',
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _pendentes.remove(d)),
            ),
          ),
        ),
      if (_podeEditar)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _busy ? null : _anexarPendente,
            icon: const Icon(Icons.attach_file),
            label: const Text('Anexar documento'),
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final ler = !_podeEditar;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _atual == null ? 'Novo produto' : 'Produto',
              style: tt.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nome,
              readOnly: ler,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _caracteristica,
              readOnly: ler,
              decoration: const InputDecoration(
                labelText: 'Característica (opcional)',
                hintText: 'lata 33cl, garrafa 1L, sabor limão…',
              ),
            ),
            const SizedBox(height: 8),
            AutocompleteTextField(
              controller: _categoria,
              options: ref.watch(categoriasConsumivelConhecidasProvider),
              readOnly: ler,
              labelText: 'Categoria',
              helperText:
                  'Escreve uma nova se a que precisas não estiver na lista '
                  '(ex.: Bebida, Revenda).',
              helperMaxLines: 2,
              onChanged: (v) => setState(() {
                if (_atual == null) _exigeFds = exigeFdsPorOmissaoPara(v);
              }),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Exige ficha de dados de segurança'),
              subtitle: const Text(
                'Produtos químicos (limpeza, desinfeção) têm de ter a FDS '
                'do fornecedor.',
              ),
              value: _exigeFds,
              onChanged: ler ? null : (v) => setState(() => _exigeFds = v),
            ),
            AutocompleteTextField(
              controller: _marca,
              options: ref.watch(marcasConhecidasProvider),
              readOnly: ler,
              labelText: 'Marca',
            ),
            const SizedBox(height: 8),
            AutocompleteTextField(
              controller: _fornecedor,
              options: ref.watch(fornecedoresConhecidosProvider),
              readOnly: ler,
              labelText: 'Fornecedor',
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _embalagem,
                    readOnly: ler,
                    decoration: const InputDecoration(
                      labelText: 'Embalagem',
                      hintText: '5 L',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _preco,
                    readOnly: ler,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Preço de compra (€)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _precoVenda,
              readOnly: ler,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Preço de venda (€, opcional)',
                helperText:
                    'Para produtos revendidos ao cliente (Bebidas, Revenda…) '
                    '— dá para ver a margem.',
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notas,
              readOnly: ler,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notas de uso',
                hintText: 'Diluição, onde se usa, EPI…',
              ),
            ),
            if (_erro != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _erro!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_podeEditar) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: _busy ? null : _guardar,
                    child: Text(
                      _atual == null ? 'Guardar' : 'Guardar alterações',
                    ),
                  ),
                  if (_atual != null)
                    TextButton(
                      onPressed: _busy ? null : _apagar,
                      child: const Text('Apagar'),
                    ),
                ],
              ),
            ],
            const Divider(height: 32),
            if (_pendentes.isNotEmpty || _atual == null) _blocoPendentes(tt),
            if (_atual != null)
              DocumentosSection(consumivel: _atual!, podeEditar: _podeEditar),
          ],
        ),
      ),
    );
  }
}

/// Lista de documentos de um consumível + anexar/abrir/apagar.
class DocumentosSection extends ConsumerWidget {
  const DocumentosSection({
    super.key,
    required this.consumivel,
    required this.podeEditar,
  });

  final Consumivel consumivel;
  final bool podeEditar;

  Future<void> _abrir(
    BuildContext context,
    WidgetRef ref,
    DocumentoConsumivel d,
  ) async {
    try {
      final url = await ref.read(consumivelActionsProvider).urlDocumento(d);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o documento.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final docs = ref.watch(documentosDoConsumivelProvider(consumivel.id));
    final ap = apresentaEstadoFds(estadoFds(consumivel, docs), cs);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Documentos (${docs.length})', style: tt.titleSmall),
            ),
            Icon(ap.icone, size: 18, color: ap.cor),
            const SizedBox(width: 4),
            Text(ap.texto, style: TextStyle(color: ap.cor)),
          ],
        ),
        if (consumivel.exigeFds &&
            estadoFds(consumivel, docs) == EstadoFds.antiga)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'A FDS tem mais de 3 anos: pede ao fornecedor a versão mais '
              'recente, se existir.',
              style: tt.bodySmall,
            ),
          ),
        const SizedBox(height: 8),
        for (final d in docs)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              leading: Icon(
                d.tipo == TipoDocumento.fds
                    ? Icons.health_and_safety_outlined
                    : Icons.description_outlined,
              ),
              title: Text(d.nomeVisivel),
              subtitle: Text(
                [
                  d.tipo.label,
                  if (d.versao.isNotEmpty) 'v. ${d.versao}',
                  _dataCurta(d.dataEfetiva),
                ].join(' · '),
              ),
              onTap: () => _abrir(context, ref, d),
              trailing: podeEditar
                  ? IconButton(
                      tooltip: 'Apagar documento',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final ok = await confirmDialog(
                          context,
                          titulo: 'Apagar documento?',
                          mensagem: 'Remove "${d.nomeVisivel}" deste produto.',
                          confirmar: 'Apagar',
                          destrutivo: true,
                        );
                        if (ok) {
                          await ref
                              .read(consumivelActionsProvider)
                              .apagarDocumento(d.id);
                        }
                      },
                    )
                  : null,
            ),
          ),
        if (podeEditar)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _AnexarDialog(consumivel: consumivel),
              ),
              icon: const Icon(Icons.attach_file),
              label: const Text('Anexar documento'),
            ),
          ),
      ],
    );
  }
}

class _AnexarDialog extends ConsumerStatefulWidget {
  const _AnexarDialog({this.consumivel});

  /// Produto já guardado a que anexar; `null` = devolve o documento por enviar.
  final Consumivel? consumivel;

  @override
  ConsumerState<_AnexarDialog> createState() => _AnexarDialogState();
}

class _AnexarDialogState extends ConsumerState<_AnexarDialog> {
  TipoDocumento _tipo = TipoDocumento.fds;
  final _titulo = TextEditingController();
  final _versao = TextEditingController();
  DateTime? _data;
  PlatformFile? _ficheiro;
  bool _busy = false;
  String? _erro;

  @override
  void dispose() {
    _titulo.dispose();
    _versao.dispose();
    super.dispose();
  }

  Future<void> _escolher() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final f = r?.files.firstOrNull;
    if (f != null) setState(() => _ficheiro = f);
  }

  Future<void> _escolherData() async {
    final agora = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _data ?? agora,
      firstDate: DateTime(2000),
      lastDate: agora,
    );
    if (d != null) setState(() => _data = d);
  }

  Future<void> _guardar() async {
    final f = _ficheiro;
    if (f == null || f.bytes == null) {
      setState(() => _erro = 'Escolhe o ficheiro (PDF ou imagem).');
      return;
    }
    if (f.size > 20 * 1024 * 1024) {
      setState(() => _erro = 'O ficheiro é grande demais (máximo 20 MB).');
      return;
    }
    if (widget.consumivel == null) {
      Navigator.pop(
        context,
        DocumentoPendente(
          tipo: _tipo,
          ficheiro: f,
          titulo: _titulo.text.trim(),
          versao: _versao.text.trim(),
          data: _data,
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _erro = null;
    });
    try {
      await ref
          .read(consumivelActionsProvider)
          .anexar(
            consumivelId: widget.consumivel!.id,
            tipo: _tipo,
            bytes: f.bytes!,
            nomeFicheiro: f.name,
            titulo: _titulo.text,
            versao: _versao.text,
            dataDocumento: _data,
          );
      if (mounted) Navigator.pop(context);
    } on Object {
      if (mounted) {
        setState(() => _erro = 'Não foi possível anexar. Tenta de novo.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Anexar documento'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<TipoDocumento>(
              initialValue: _tipo,
              decoration: const InputDecoration(labelText: 'Tipo'),
              isExpanded: true,
              items: [
                for (final t in TipoDocumento.values)
                  DropdownMenuItem(value: t, child: Text(t.label)),
              ],
              onChanged: (v) => setState(() => _tipo = v ?? _tipo),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titulo,
              decoration: const InputDecoration(labelText: 'Título (opcional)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _versao,
              decoration: const InputDecoration(
                labelText: 'Versão / revisão (opcional)',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _escolherData,
                  icon: const Icon(Icons.event),
                  label: Text(
                    _data == null ? 'Data do documento' : _dataCurta(_data),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _escolher,
                  icon: const Icon(Icons.upload_file),
                  label: Text(_ficheiro?.name ?? 'Escolher ficheiro'),
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
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _busy ? null : _guardar,
          child: const Text('Anexar'),
        ),
      ],
    );
  }
}
