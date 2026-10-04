import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/errors/mensagem_amigavel.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../application/recipes_providers.dart';
import '../data/recipe_repository.dart';
import '../domain/recipe.dart';

/// Folha com o passo-a-passo da receita e a galeria de imagens.
Future<void> showProcedimentoSheet(BuildContext context, Receita receita) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ProcedimentoSheet(receitaId: receita.id),
  );
}

class _ProcedimentoSheet extends ConsumerStatefulWidget {
  const _ProcedimentoSheet({required this.receitaId});
  final String receitaId;

  @override
  ConsumerState<_ProcedimentoSheet> createState() => _ProcedimentoSheetState();
}

class _ProcedimentoSheetState extends ConsumerState<_ProcedimentoSheet> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _adicionar() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: true,
    );
    final ficheiros = picked?.files
        .where((f) => f.bytes != null)
        .map((f) => (nome: f.name, bytes: f.bytes!.toList()))
        .toList();
    if (ficheiros == null || ficheiros.isEmpty) return;
    await _run(
      () => ref
          .read(recipeActionsProvider)
          .adicionarImagens(widget.receitaId, ficheiros),
    );
  }

  Future<void> _editarProcedimento(Receita receita) async {
    final ctrl = TextEditingController(text: receita.procedimento);
    final novo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Procedimento'),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            maxLines: 12,
            minLines: 6,
            decoration: const InputDecoration(
              hintText: 'Um passo por linha…',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (novo == null || novo == receita.procedimento) return;
    await _run(
      () => ref
          .read(recipeActionsProvider)
          .setProcedimento(widget.receitaId, novo),
    );
  }

  Future<void> _remover(String nome) async {
    final ok = await confirmDialog(
      context,
      titulo: 'Remover imagem',
      mensagem: 'Remover esta imagem da receita?',
      confirmar: 'Remover',
      destrutivo: true,
    );
    if (!ok) return;
    await _run(
      () =>
          ref.read(recipeActionsProvider).removerImagem(widget.receitaId, nome),
    );
  }

  Future<void> _substituir(String nomeAntigo) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final novo =
        (picked != null && picked.files.isNotEmpty) ? picked.files.first : null;
    if (novo?.bytes == null) return;
    await _run(() async {
      final actions = ref.read(recipeActionsProvider);
      await actions.removerImagem(widget.receitaId, nomeAntigo);
      await actions.adicionarImagens(widget.receitaId, [
        (nome: novo!.name, bytes: novo.bytes!.toList()),
      ]);
    });
  }

  void _verGrande(String url) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }

  Future<void> _abrirOpcoesImagem(String nome, String url) async {
    final opcao = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.zoom_in_outlined),
              title: const Text('Ver em grande'),
              onTap: () => Navigator.pop(context, 'ver'),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Substituir'),
              onTap: () => Navigator.pop(context, 'substituir'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remover'),
              onTap: () => Navigator.pop(context, 'remover'),
            ),
          ],
        ),
      ),
    );
    switch (opcao) {
      case 'ver':
        _verGrande(url);
      case 'substituir':
        await _substituir(nome);
      case 'remover':
        await _remover(nome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(recipeDetailProvider(widget.receitaId));
    final repo = ref.read(recipeRepositoryProvider);
    final podeEditar = ref.watch(currentPapelProvider).canEditBusiness;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(mensagemAmigavel(e))),
        data: (d) {
          final receita = d.receita;
          final passos = receita.passos;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_busy) const LinearProgressIndicator(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  receita.nome,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Procedimento',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (podeEditar)
                          TextButton.icon(
                            onPressed:
                                _busy ? null : () => _editarProcedimento(receita),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Editar'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (passos.isEmpty)
                      Text(
                        'Sem passos.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    else
                      for (var i = 0; i < passos.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 26,
                                child: Text(
                                  '${i + 1}.',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(child: Text(passos[i])),
                            ],
                          ),
                        ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Imagens',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (podeEditar)
                          TextButton.icon(
                            onPressed: _busy ? null : _adicionar,
                            icon: const Icon(Icons.add_a_photo_outlined),
                            label: const Text('Adicionar'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (receita.imagens.isEmpty)
                      Text(
                        'Sem imagens.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final nome in receita.imagens)
                            _Miniatura(
                              thumbUrl: repo.imagemUrl(
                                receita.id,
                                nome,
                                thumb: true,
                              ),
                              onTap: podeEditar
                                  ? () => _abrirOpcoesImagem(
                                        nome,
                                        repo.imagemUrl(receita.id, nome),
                                      )
                                  : () => _verGrande(
                                        repo.imagemUrl(receita.id, nome),
                                      ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.thumbUrl, required this.onTap});

  final String thumbUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          thumbUrl,
          width: 104,
          height: 104,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 104,
            height: 104,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Icon(Icons.broken_image_outlined),
          ),
        ),
      ),
    );
  }
}
