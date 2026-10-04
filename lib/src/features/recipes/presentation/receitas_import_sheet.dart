import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_clipboard/super_clipboard.dart';

import '../../../core/errors/mensagem_amigavel.dart';
import '../../import_csv/domain/import_result.dart';
import '../../invoices/domain/invoice_erros.dart';
import '../../recipe_categories/application/categoria_receita_providers.dart';
import '../application/receitas_import_service.dart';

/// Folha para importar receitas: uma receita só (nome + lista simples de
/// ingredientes, à mão ou pré-preenchida por IA a partir de uma imagem), ou
/// várias de uma vez (CSV/texto colado no formato avançado de 4 colunas).
Future<void> showImportarReceitasSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => const _ImportarReceitasSheet(),
  );
}

enum _Modo { uma, csv }

class _ImportarReceitasSheet extends ConsumerStatefulWidget {
  const _ImportarReceitasSheet();

  @override
  ConsumerState<_ImportarReceitasSheet> createState() =>
      _ImportarReceitasSheetState();
}

class _ImportarReceitasSheetState
    extends ConsumerState<_ImportarReceitasSheet> {
  _Modo _modo = _Modo.uma;
  bool _busy = false;

  // modo "uma receita"
  final _nomeReceita = TextEditingController();
  final _textoIngredientes = TextEditingController();
  String? _categoria;
  final _colarFocus = FocusNode();
  bool _lendoImagem = false;
  void Function(ClipboardReadEvent)? _pasteListener;

  // modo "várias (CSV)"
  final _texto = TextEditingController();

  @override
  void initState() {
    super.initState();
    final events = ClipboardEvents.instance;
    if (events != null) {
      _pasteListener = _aoColar;
      events.registerPasteEventListener(_pasteListener!);
    }
  }

  @override
  void dispose() {
    final l = _pasteListener;
    if (l != null) ClipboardEvents.instance?.unregisterPasteEventListener(l);
    _nomeReceita.dispose();
    _textoIngredientes.dispose();
    _colarFocus.dispose();
    _texto.dispose();
    super.dispose();
  }

  /// Só intercepta o Ctrl+V quando a área "cola aqui" tem o foco — senão o
  /// colar normal de texto nos campos (nome, lista de ingredientes) tem de
  /// continuar a funcionar como sempre.
  void _aoColar(ClipboardReadEvent event) {
    if (!_colarFocus.hasFocus) return;
    unawaited(_lerDoEvento(event));
  }

  Future<void> _lerDoEvento(ClipboardReadEvent event) async {
    final reader = await event.getClipboardReader();
    for (final f in const [
      Formats.png,
      Formats.jpeg,
      Formats.webp,
      Formats.gif,
    ]) {
      if (reader.canProvide(f)) {
        reader.getFile(f, (file) async {
          final bytes = await file.readAll();
          await _processarImagem(bytes, file.fileName ?? 'colado.png');
        });
        return;
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sem imagem no que colaste.')),
      );
    }
  }

  Future<void> _escolherImagem() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final f = (picked != null && picked.files.isNotEmpty)
        ? picked.files.first
        : null;
    if (f == null || f.bytes == null) return;
    await _processarImagem(f.bytes!, f.name);
  }

  Future<void> _processarImagem(Uint8List bytes, String nome) async {
    if (!mounted) return;
    setState(() => _lendoImagem = true);
    try {
      final r = await ref
          .read(receitasImportServiceProvider)
          .lerImagem(bytes: bytes, nome: nome);
      if (!mounted) return;
      final categorias = ref.read(categoriasReceitaAtivasProvider).valueOrNull;
      setState(() {
        if (r.nome.isNotEmpty && _nomeReceita.text.trim().isEmpty) {
          _nomeReceita.text = r.nome;
        }
        if (r.categoria.isNotEmpty && categorias != null) {
          final m = categorias.where(
            (c) => c.nome.toLowerCase() == r.categoria.toLowerCase(),
          );
          if (m.isNotEmpty) _categoria = m.first.nome;
        }
        if (r.ingredientes.isNotEmpty) {
          _textoIngredientes.text = [
            for (final i in r.ingredientes)
              '${i.nome}\t${i.quantidadeG.toStringAsFixed(0)}',
          ].join('\n');
        }
      });
      if (r.ingredientes.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A IA não encontrou nenhum ingrediente na imagem.'),
          ),
        );
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
      }
    } finally {
      if (mounted) setState(() => _lendoImagem = false);
    }
  }

  Future<void> _mostrarResultado(ImportResult r) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importação de receitas'),
        content: SingleChildScrollView(
          child: Text(
            r.semErros
                ? r.resumo
                : '${r.resumo}\n\n'
                      '${r.erros.take(12).join('\n')}'
                      '${r.erros.length > 12 ? '\n…' : ''}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ok'),
          ),
        ],
      ),
    );
    if (mounted && r.criados > 0) Navigator.pop(context);
  }

  Future<void> _importarUma() async {
    setState(() => _busy = true);
    try {
      final r = await ref
          .read(receitasImportServiceProvider)
          .importarUma(
            nome: _nomeReceita.text,
            categoria: _categoria ?? '',
            textoIngredientes: _textoIngredientes.text,
          );
      await _mostrarResultado(r);
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _escolherFicheiroCsv() async {
    try {
      final conteudo = await ref.read(receitasImportServiceProvider).pickCsv();
      if (mounted) setState(() => _texto.text = conteudo);
    } on ImportCancelled {
      // nada escolhido
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
      }
    }
  }

  Future<void> _importarCsv() async {
    setState(() => _busy = true);
    try {
      final r = await ref
          .read(receitasImportServiceProvider)
          .importCsv(_texto.text);
      await _mostrarResultado(r);
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_busy) const LinearProgressIndicator(),
            Text('Importar receitas', style: tt.titleLarge),
            const SizedBox(height: 10),
            SegmentedButton<_Modo>(
              segments: const [
                ButtonSegment(value: _Modo.uma, label: Text('Uma receita')),
                ButtonSegment(
                  value: _Modo.csv,
                  label: Text('Várias (CSV avançado)'),
                ),
              ],
              selected: {_modo},
              onSelectionChanged: (s) => setState(() => _modo = s.first),
            ),
            const SizedBox(height: 12),
            if (_modo == _Modo.uma) _modoUma(tt) else _modoCsv(tt),
          ],
        ),
      ),
    );
  }

  Widget _modoUma(TextTheme tt) {
    final categoriasAsync = ref.watch(categoriasReceitaAtivasProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Escreve o nome, escolhe a categoria, e cola/escreve a lista de '
          'ingredientes (nome e quantidade em gramas, uma linha por '
          'ingrediente). Podes também mandar uma imagem — print da folha de '
          'cálculo, ou foto de uma lista escrita — e a IA pré-preenche tudo '
          'para reveres antes de importar.',
          style: tt.bodySmall,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nomeReceita,
          decoration: const InputDecoration(
            labelText: 'Nome da receita',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        Text('Categoria', style: tt.bodySmall),
        const SizedBox(height: 4),
        categoriasAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) =>
              const Text('Não foi possível carregar as categorias.'),
          data: (categorias) {
            if (categorias.isEmpty) {
              return const Text(
                'Sem categorias ativas. Cria uma em Configurações → '
                'Categorias de receitas.',
              );
            }
            return Wrap(
              spacing: 8,
              children: [
                for (final c in categorias)
                  ChoiceChip(
                    label: Text(c.nome),
                    selected: _categoria == c.nome,
                    onSelected: (_) => setState(() => _categoria = c.nome),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _lendoImagem || _busy ? null : _escolherImagem,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Escolher imagem'),
              ),
            ),
            if (_lendoImagem) ...[
              const SizedBox(width: 12),
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _colarFocus,
          builder: (context, _) {
            final cs = Theme.of(context).colorScheme;
            final focado = _colarFocus.hasFocus;
            return Focus(
              focusNode: _colarFocus,
              child: GestureDetector(
                onTap: () => _colarFocus.requestFocus(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: focado ? cs.primary : cs.outlineVariant,
                      width: focado ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.content_paste, color: cs.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          focado
                              ? 'Pronto — cola com Ctrl+V (ou Cmd+V)'
                              : 'Toca aqui e cola uma imagem com Ctrl+V',
                          style: tt.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _textoIngredientes,
          minLines: 6,
          maxLines: 10,
          decoration: const InputDecoration(
            labelText: 'Ingredientes (nome + quantidade em gramas)',
            hintText: 'Açucar Branco\t30\nCacau em pó\t30',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy ? null : _importarUma,
          child: const Text('Importar'),
        ),
      ],
    );
  }

  Widget _modoCsv(TextTheme tt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Uma linha por ingrediente: nome da receita, categoria, '
          'ingrediente e quantidade em gramas (separados por tab, ; ou ,). '
          'Podes colar direto da folha de cálculo. Ingredientes sem '
          'correspondência ficam pendentes para ligares depois.',
          style: tt.bodySmall,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _texto,
          minLines: 6,
          maxLines: 10,
          decoration: const InputDecoration(
            hintText: 'Massa_Normandia\tMassas\tManteiga\t191',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _busy ? null : _escolherFicheiroCsv,
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('Escolher ficheiro CSV'),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _busy ? null : _importarCsv,
          child: const Text('Importar'),
        ),
      ],
    );
  }
}
