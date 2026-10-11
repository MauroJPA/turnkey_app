import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/mensagem_amigavel.dart';
import '../../../core/widgets/desfazer.dart';
import '../application/quadros_providers.dart';
import '../data/quadros_repository.dart';

/// O máximo de imagens por tarefa (o mesmo do servidor).
const maxImagensTarefa = 8;

const _maxBytes = 10 * 1024 * 1024;
const _extensoes = {'jpg', 'jpeg', 'png', 'webp'};

/// As imagens de uma tarefa: miniaturas, "Juntar imagem" (galeria ou câmara) e
/// ver em ponto grande. Grava logo (sem botão "Guardar"); tirar uma imagem tem
/// "Desfazer".
class ImagensTarefa extends ConsumerStatefulWidget {
  const ImagensTarefa({
    super.key,
    required this.tarefaId,
    required this.quadroId,
    required this.imagens,
    required this.pode,
    required this.onMudou,
  });

  final String tarefaId;
  final String quadroId;

  /// Os nomes dos ficheiros que a tarefa já tem.
  final List<String> imagens;
  final bool pode;

  /// A lista nova, depois de juntar ou tirar.
  final ValueChanged<List<String>> onMudou;

  @override
  ConsumerState<ImagensTarefa> createState() => _ImagensTarefaState();
}

class _ImagensTarefaState extends ConsumerState<ImagensTarefa> {
  late final QuadrosRepository _repo = ref.read(quadrosRepositoryProvider);
  late final ProviderContainer _container = ProviderScope.containerOf(
    context,
    listen: false,
  );
  bool _aEnviar = false;

  @override
  void initState() {
    super.initState();
    _container; // apanhado já, para o usar depois de a folha fechar
  }

  void _atualizarQuadro() =>
      _container.invalidate(dadosQuadroProvider(widget.quadroId));

  void _erro(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
  }

  Future<void> _juntar() async {
    final messenger = ScaffoldMessenger.of(context);
    final FilePickerResult? escolhidas;
    try {
      escolhidas = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
        allowMultiple: true,
      );
    } on Object catch (e) {
      _erro(e);
      return;
    }
    if (escolhidas == null || !mounted) return;

    final livres = maxImagensTarefa - widget.imagens.length;
    final novas = <({String nome, List<int> bytes})>[];
    var formato = 0, grandes = 0, demais = 0;
    for (final f in escolhidas.files) {
      final bytes = f.bytes;
      if (bytes == null) continue;
      if (!_extensoes.contains((f.extension ?? '').toLowerCase())) {
        formato++;
      } else if (bytes.length > _maxBytes) {
        grandes++;
      } else if (novas.length >= livres) {
        demais++;
      } else {
        novas.add((nome: f.name, bytes: bytes));
      }
    }

    if (novas.isNotEmpty) {
      setState(() => _aEnviar = true);
      try {
        final t = await _repo.adicionarImagens(widget.tarefaId, novas);
        if (mounted) widget.onMudou(t.imagens);
        _atualizarQuadro();
      } on Object catch (e) {
        _erro(e);
      } finally {
        if (mounted) setState(() => _aEnviar = false);
      }
    }

    final avisos = [
      if (formato > 0) '$formato sem ser JPG, PNG ou WebP',
      if (grandes > 0) '$grandes com mais de 10 MB',
      if (demais > 0) '$demais além das $maxImagensTarefa por tarefa',
    ];
    if (avisos.isNotEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text('Ficaram de fora: ${avisos.join(', ')}.')),
      );
    }
  }

  Future<void> _tirar(String nome) => apagarComDesfazer(
    context,
    id: nome,
    mensagem: 'Imagem tirada.',
    apagar: () => _repo.removerImagem(widget.tarefaId, nome),
    depois: () {
      if (mounted) {
        widget.onMudou([
          for (final i in widget.imagens)
            if (i != nome) i,
        ]);
      }
      _atualizarQuadro();
    },
    aoFalhar: _erro,
  );

  void _ver(List<String> nomes, int indice) => showDialog<void>(
    context: context,
    builder: (_) =>
        _VisorImagens(tarefaId: widget.tarefaId, nomes: nomes, inicial: indice),
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ocultas = ref.watch(ocultosProvider);
    final nomes = [
      for (final n in widget.imagens)
        if (!ocultas.contains(n)) n,
    ];
    final token = nomes.isEmpty
        ? null
        : ref.watch(tokenImagensProvider).valueOrNull;

    Widget miniatura(int i) {
      final nome = nomes[i];
      final vazio = Container(
        width: 80,
        height: 80,
        color: cs.surfaceContainerHighest,
        child: Icon(Icons.image_outlined, color: cs.onSurfaceVariant),
      );
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Tooltip(
            message: 'Ver a imagem',
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _ver(nomes, i),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: token == null
                    ? vazio
                    : Image.network(
                        _repo.urlImagem(
                          widget.tarefaId,
                          nome,
                          token: token,
                          thumb: true,
                        ),
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        gaplessPlayback:
                            true, // sem piscar quando renova o token
                        errorBuilder: (_, __, ___) => vazio,
                      ),
              ),
            ),
          ),
          if (widget.pode)
            Positioned(
              right: -8,
              top: -8,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _tirar(nome),
                child: Tooltip(
                  message: 'Tirar a imagem',
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: cs.surfaceContainerHighest,
                    foregroundColor: cs.onSurface,
                    child: const Icon(Icons.close, size: 14),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < nomes.length; i++) miniatura(i),
        if (widget.pode && nomes.length < maxImagensTarefa)
          ActionChip(
            avatar: _aEnviar
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_photo_alternate_outlined, size: 18),
            label: Text(_aEnviar ? 'A enviar…' : 'Juntar imagem'),
            onPressed: _aEnviar ? null : _juntar,
          ),
        if (!widget.pode && nomes.isEmpty)
          Text('Sem imagens', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Uma imagem em ponto grande (com zoom e setas para as outras da tarefa).
class _VisorImagens extends ConsumerStatefulWidget {
  const _VisorImagens({
    required this.tarefaId,
    required this.nomes,
    required this.inicial,
  });

  final String tarefaId;
  final List<String> nomes;
  final int inicial;

  @override
  ConsumerState<_VisorImagens> createState() => _VisorImagensState();
}

class _VisorImagensState extends ConsumerState<_VisorImagens> {
  late int _i = widget.inicial;

  void _ir(int passo) {
    final n = widget.nomes.length;
    setState(() => _i = (_i + passo + n) % n);
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(tokenImagensProvider).valueOrNull;
    final repo = ref.read(quadrosRepositoryProvider);
    final varias = widget.nomes.length > 1;

    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: token == null
                ? const Center(child: CircularProgressIndicator())
                : InteractiveViewer(
                    key: ValueKey(_i),
                    minScale: 1,
                    maxScale: 5,
                    child: Center(
                      child: Image.network(
                        repo.urlImagem(
                          widget.tarefaId,
                          widget.nomes[_i],
                          token: token,
                        ),
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        loadingBuilder: (_, filho, progresso) =>
                            progresso == null
                            ? filho
                            : const Center(child: CircularProgressIndicator()),
                        errorBuilder: (_, __, ___) => const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Não foi possível abrir a imagem.',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          if (varias)
            Positioned(
              left: 4,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton.filledTonal(
                  tooltip: 'Anterior',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _ir(-1),
                ),
              ),
            ),
          if (varias)
            Positioned(
              right: 4,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton.filledTonal(
                  tooltip: 'Seguinte',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _ir(1),
                ),
              ),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (varias)
                      Text(
                        '${_i + 1} / ${widget.nomes.length}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    IconButton.filledTonal(
                      tooltip: 'Fechar',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
