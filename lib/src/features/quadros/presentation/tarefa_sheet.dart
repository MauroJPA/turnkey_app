import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/cores_estado.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/errors/mensagem_amigavel.dart';
import '../../../core/widgets/desfazer.dart';
import '../../people/domain/nota.dart' show quandoTexto;
import '../application/quadros_providers.dart';
import '../data/quadros_repository.dart';
import '../domain/quadro.dart';
import 'quadro_comum.dart';

/// Abre o detalhe de uma tarefa numa folha que sobe de baixo.
Future<void> abrirTarefa(
  BuildContext context, {
  required Tarefa tarefa,
  required List<ColunaQuadro> colunas,
  required List<Tarefa> todas,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => FractionallySizedBox(
    heightFactor: 0.94,
    child: TarefaSheet(tarefa: tarefa, colunas: colunas, todas: todas),
  ),
);

/// O detalhe de uma tarefa. Tudo se grava sozinho (sem botão "Guardar").
class TarefaSheet extends ConsumerStatefulWidget {
  const TarefaSheet({
    super.key,
    required this.tarefa,
    required this.colunas,
    required this.todas,
  });

  final Tarefa tarefa;
  final List<ColunaQuadro> colunas;

  /// As tarefas do quadro (para sugerir etiquetas e pôr no fim da fase).
  final List<Tarefa> todas;

  @override
  ConsumerState<TarefaSheet> createState() => _TarefaSheetState();
}

class _TarefaSheetState extends ConsumerState<TarefaSheet> {
  late Tarefa _t = widget.tarefa;
  late final QuadrosRepository _repo = ref.read(quadrosRepositoryProvider);
  late final ProviderContainer _container = ProviderScope.containerOf(
    context,
    listen: false,
  );
  late final _titulo = TextEditingController(text: _t.titulo);
  late final _descricao = TextEditingController(text: _t.descricao);
  final _novoItem = TextEditingController();
  final _novoItemFoco = FocusNode();
  final _comentario = TextEditingController();
  final _comentarioFoco = FocusNode();
  Timer? _espera;
  bool _porGravar = false;
  bool _aEnviar = false;
  bool _lidasMarcadas = false;

  @override
  void initState() {
    super.initState();
    _container; // apanhado já, para o gravar no fim (depois de fechar)
  }

  @override
  void dispose() {
    _espera?.cancel();
    if (_porGravar) unawaited(_gravarAgora());
    _titulo.dispose();
    _descricao.dispose();
    _novoItem.dispose();
    _novoItemFoco.dispose();
    _comentario.dispose();
    _comentarioFoco.dispose();
    super.dispose();
  }

  void _atualizarQuadro() =>
      _container.invalidate(dadosQuadroProvider(_t.quadroId));

  void _erro(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
  }

  /// Muda a tarefa e grava daqui a pouco (várias mudanças seguidas = uma só
  /// gravação).
  void _mudar(Tarefa nova, {bool ja = false}) {
    setState(() => _t = nova);
    _porGravar = true;
    _espera?.cancel();
    _espera = Timer(
      ja ? Duration.zero : const Duration(milliseconds: 700),
      () => unawaited(_gravarAgora()),
    );
  }

  Future<void> _gravarAgora() async {
    _espera?.cancel();
    if (!_porGravar) return;
    _porGravar = false;
    final t = _t.copyWith(
      titulo: _titulo.text.trim().isEmpty ? widget.tarefa.titulo : _titulo.text,
      descricao: _descricao.text,
    );
    try {
      await _repo.guardar(t);
      _atualizarQuadro();
    } on Object catch (e) {
      _erro(e);
    }
  }

  void _moverPara(ColunaQuadro c) {
    if (c.id == _t.colunaId) return;
    final destino = tarefasDaColuna(widget.todas, c.id);
    _mudar(
      _t.copyWith(
        colunaId: c.id,
        ordem: ordemNoFim([for (final x in destino) x.ordem]),
      ),
      ja: true,
    );
  }

  Future<void> _escolherPessoas(List<PessoaEquipa> pessoas) async {
    final escolhidos = {..._t.responsaveis};
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Responsáveis',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final p in pessoas)
                      CheckboxListTile(
                        value: escolhidos.contains(p.id),
                        secondary: AvatarPessoa(p, raio: 16),
                        title: Text(p.nome),
                        onChanged: (v) => setS(
                          () => v == true
                              ? escolhidos.add(p.id)
                              : escolhidos.remove(p.id),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Feito'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) {
      _mudar(
        _t.copyWith(
          responsaveis: [
            for (final p in pessoas)
              if (escolhidos.contains(p.id)) p.id,
            // quem já não está na equipa mantém-se até alguém o tirar
            for (final r in _t.responsaveis)
              if (!pessoas.any((p) => p.id == r) && escolhidos.contains(r)) r,
          ],
        ),
        ja: true,
      );
    }
  }

  Future<void> _escolherPrazo() async {
    final hoje = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _t.prazo ?? hoje,
      firstDate: DateTime(hoje.year - 1),
      lastDate: DateTime(hoje.year + 3),
    );
    if (d != null) _mudar(_t.copyWith(prazo: d), ja: true);
  }

  Future<void> _novaEtiqueta() async {
    final sugeridas = [
      for (final e in etiquetasUsadas(widget.todas))
        if (!_t.etiquetas.any(
          (x) => semAcentos(x.toLowerCase()) == semAcentos(e.toLowerCase()),
        ))
          e,
    ];
    final ctrl = TextEditingController();
    final nome = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Etiqueta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLength: 30,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Ex.: Urgente, Loja, Fornecedor',
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
            if (sugeridas.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in sugeridas.take(12))
                    InkWell(
                      onTap: () => Navigator.pop(ctx, e),
                      child: EtiquetaPilula(e),
                    ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Pôr'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    final n = nome?.trim() ?? '';
    if (n.isEmpty) return;
    if (_t.etiquetas.any(
      (x) => semAcentos(x.toLowerCase()) == semAcentos(n.toLowerCase()),
    )) {
      return;
    }
    _mudar(_t.copyWith(etiquetas: [..._t.etiquetas, n]), ja: true);
  }

  void _adicionarItem() {
    final txt = _novoItem.text.trim();
    if (txt.isEmpty) return;
    _novoItem.clear();
    _mudar(_t.copyWith(checklist: [..._t.checklist, ItemChecklist(txt)]));
    _novoItemFoco.requestFocus();
  }

  Future<void> _enviarComentario(List<PessoaEquipa> pessoas) async {
    final txt = _comentario.text.trim();
    if (txt.isEmpty || _aEnviar) return;
    setState(() => _aEnviar = true);
    try {
      await _repo.comentar(
        _t.id,
        txt,
        mencoes: mencoesNoTexto(txt, pessoas),
        autorNome: ref.read(currentUserNameProvider) ?? '',
      );
      _comentario.clear();
      ref.invalidate(comentariosTarefaProvider(_t.id));
      _atualizarQuadro();
    } on Object catch (e) {
      _erro(e);
    } finally {
      if (mounted) setState(() => _aEnviar = false);
    }
  }

  Future<void> _editarComentario(
    ComentarioTarefa c,
    List<PessoaEquipa> pessoas,
  ) async {
    final ctrl = TextEditingController(text: c.texto);
    final novo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar comentário'),
        content: SizedBox(
          width: 420,
          child: CampoMencoes(
            controller: ctrl,
            pessoas: pessoas,
            minLines: 2,
            autofocus: true,
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
    ctrl.dispose();
    if (novo == null || novo.trim().isEmpty || novo.trim() == c.texto) return;
    try {
      await _repo.editarComentario(
        c.id,
        novo,
        mencoes: mencoesNoTexto(novo, pessoas),
      );
      ref.invalidate(comentariosTarefaProvider(_t.id));
      _atualizarQuadro();
    } on Object catch (e) {
      _erro(e);
    }
  }

  Future<void> _arquivar() async {
    final messenger = ScaffoldMessenger.of(context);
    final id = _t.id;
    _espera?.cancel();
    await _gravarAgora();
    try {
      await _repo.arquivarTarefa(id, arquivada: true);
    } on Object catch (e) {
      _erro(e);
      return;
    }
    _atualizarQuadro();
    if (mounted) Navigator.pop(context);
    await mostrarDesfazerEm(
      messenger,
      mensagem: 'Tarefa arquivada.',
      desfazer: () async {
        await _repo.arquivarTarefa(id, arquivada: false);
        _atualizarQuadro();
      },
    );
  }

  Future<void> _apagar() async {
    final id = _t.id;
    _espera?.cancel();
    _porGravar = false;
    final nav = Navigator.of(context);
    final ctxQuadro = nav.context;
    nav.pop();
    await apagarComDesfazer(
      ctxQuadro,
      id: id,
      mensagem: 'Tarefa apagada.',
      apagar: () => _repo.apagarTarefa(id),
      depois: _atualizarQuadro,
      aoFalhar: (e) {
        if (ctxQuadro.mounted) {
          ScaffoldMessenger.of(
            ctxQuadro,
          ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final papel = ref.watch(currentPapelProvider);
    final pode = papel.canEditBusiness;
    final uid = _repo.utilizadorId;
    final pessoas = ref.watch(pessoasEquipaProvider);
    final nomes = {for (final p in pessoas) p.id: p};
    final responsaveis = [
      for (final r in _t.responsaveis)
        nomes[r] ?? PessoaEquipa(r, '(antigo membro)'),
    ];
    final coluna = widget.colunas.where((c) => c.id == _t.colunaId).firstOrNull;
    final feita = coluna?.concluida ?? false;
    final hoje = DateTime.now();
    final podeApagar = pode && (papel.canEditConfig || _t.autorId == uid);

    final comentarios = ref.watch(comentariosTarefaProvider(_t.id));
    final lista = comentarios.valueOrNull ?? const <ComentarioTarefa>[];
    if (!_lidasMarcadas && lista.any((c) => c.mencaoPorLer(uid))) {
      _lidasMarcadas = true;
      unawaited(
        _repo
            .marcarLidas(lista)
            .then((_) => _atualizarQuadro(), onError: (_) {}),
      );
    }

    Widget seccao(String titulo, IconData icone) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Row(
        children: [
          Icon(icone, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(titulo, style: tt.labelLarge),
        ],
      ),
    );

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              TextField(
                controller: _titulo,
                enabled: pode,
                maxLength: 200,
                maxLines: null,
                style: tt.titleLarge,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Título da tarefa',
                  counterText: '',
                  border: InputBorder.none,
                  filled: false,
                ),
                onChanged: (_) => _mudar(_t),
              ),
              Text(
                [
                  if (_t.autorNome.isNotEmpty) 'Criada por ${_t.autorNome}',
                  quandoTexto(_t.criada, hoje),
                ].join(' · '),
                style: tt.bodySmall,
              ),

              seccao('Fase', Icons.view_column_outlined),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in widget.colunas)
                    ChoiceChip(
                      label: Text(c.nome),
                      avatar: c.concluida
                          ? Icon(Icons.check, size: 16, color: cs.sucesso)
                          : null,
                      selected: c.id == _t.colunaId,
                      onSelected: pode ? (_) => _moverPara(c) : null,
                    ),
                ],
              ),

              seccao('Responsáveis', Icons.person_outline),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in responsaveis)
                    InputChip(
                      avatar: AvatarPessoa(p, raio: 10),
                      label: Text(p.nome),
                      onDeleted: pode
                          ? () => _mudar(
                              _t.copyWith(
                                responsaveis: [
                                  for (final r in _t.responsaveis)
                                    if (r != p.id) r,
                                ],
                              ),
                              ja: true,
                            )
                          : null,
                    ),
                  if (pode && uid.isNotEmpty && !_t.responsaveis.contains(uid))
                    ActionChip(
                      avatar: const Icon(Icons.front_hand_outlined, size: 16),
                      label: const Text('Fico eu'),
                      onPressed: () => _mudar(
                        _t.copyWith(responsaveis: [..._t.responsaveis, uid]),
                        ja: true,
                      ),
                    ),
                  if (pode)
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 16),
                      label: const Text('Pessoa'),
                      onPressed: () => _escolherPessoas(pessoas),
                    ),
                  if (!pode && responsaveis.isEmpty)
                    Text('Ninguém', style: tt.bodySmall),
                ],
              ),

              seccao('Prazo', Icons.event_outlined),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (_t.prazo != null)
                    InputChip(
                      avatar: Icon(
                        feita ? Icons.check_circle : Icons.event,
                        size: 16,
                        color: feita
                            ? cs.sucesso
                            : _t.atrasada(hoje, feita: false)
                            ? cs.error
                            : null,
                      ),
                      label: Text(_prazoCompleto(_t.prazo!, hoje)),
                      onPressed: pode ? _escolherPrazo : null,
                      onDeleted: pode
                          ? () =>
                                _mudar(_t.copyWith(limparPrazo: true), ja: true)
                          : null,
                    )
                  else if (pode) ...[
                    ActionChip(
                      label: const Text('Hoje'),
                      onPressed: () =>
                          _mudar(_t.copyWith(prazo: hoje), ja: true),
                    ),
                    ActionChip(
                      label: const Text('Amanhã'),
                      onPressed: () => _mudar(
                        _t.copyWith(
                          prazo: DateTime(hoje.year, hoje.month, hoje.day + 1),
                        ),
                        ja: true,
                      ),
                    ),
                    ActionChip(
                      avatar: const Icon(
                        Icons.calendar_month_outlined,
                        size: 16,
                      ),
                      label: const Text('Escolher dia'),
                      onPressed: _escolherPrazo,
                    ),
                  ] else
                    Text('Sem prazo', style: tt.bodySmall),
                ],
              ),

              seccao('Etiquetas', Icons.sell_outlined),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final e in _t.etiquetas)
                    EtiquetaPilula(
                      e,
                      onApagar: pode
                          ? () => _mudar(
                              _t.copyWith(
                                etiquetas: [
                                  for (final x in _t.etiquetas)
                                    if (x != e) x,
                                ],
                              ),
                              ja: true,
                            )
                          : null,
                    ),
                  if (pode)
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 16),
                      label: const Text('Etiqueta'),
                      onPressed: _novaEtiqueta,
                    ),
                  if (!pode && _t.etiquetas.isEmpty)
                    Text('Nenhuma', style: tt.bodySmall),
                ],
              ),

              seccao('Descrição', Icons.notes_outlined),
              TextField(
                controller: _descricao,
                enabled: pode,
                minLines: 2,
                maxLines: 12,
                maxLength: 5000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Detalhes, o que é preciso, onde está…',
                  counterText: '',
                ),
                onChanged: (_) => _mudar(_t),
              ),

              seccao(
                _t.temChecklist
                    ? 'Lista (${_t.checklistFeitos}/${_t.checklist.length})'
                    : 'Lista',
                Icons.checklist,
              ),
              if (_t.temChecklist)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: LinearProgressIndicator(
                    value: _t.checklistFeitos / _t.checklist.length,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                    color: cs.sucesso,
                  ),
                ),
              for (var i = 0; i < _t.checklist.length; i++)
                Row(
                  children: [
                    Checkbox(
                      value: _t.checklist[i].feito,
                      onChanged: pode
                          ? (v) {
                              final l = [..._t.checklist];
                              l[i] = l[i].copyWith(feito: v ?? false);
                              _mudar(_t.copyWith(checklist: l), ja: true);
                            }
                          : null,
                    ),
                    Expanded(
                      child: Text(
                        _t.checklist[i].texto,
                        style: _t.checklist[i].feito
                            ? tt.bodyMedium?.copyWith(
                                decoration: TextDecoration.lineThrough,
                                color: cs.onSurfaceVariant,
                              )
                            : tt.bodyMedium,
                      ),
                    ),
                    if (pode)
                      IconButton(
                        tooltip: 'Tirar',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          final l = [..._t.checklist]..removeAt(i);
                          _mudar(_t.copyWith(checklist: l), ja: true);
                        },
                      ),
                  ],
                ),
              if (pode)
                TextField(
                  controller: _novoItem,
                  focusNode: _novoItemFoco,
                  maxLength: 200,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Adicionar um passo',
                    counterText: '',
                    isDense: true,
                    prefixIcon: const Icon(Icons.add),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.keyboard_return),
                      onPressed: _adicionarItem,
                    ),
                  ),
                  onSubmitted: (_) => _adicionarItem(),
                ),

              seccao(
                lista.isEmpty ? 'Comentários' : 'Comentários (${lista.length})',
                Icons.forum_outlined,
              ),
              if (comentarios.isLoading && lista.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Center(child: CircularProgressIndicator()),
                ),
              for (final c in lista)
                _ComentarioLinha(
                  comentario: c,
                  pessoas: pessoas,
                  autor: nomes[c.autorId],
                  meu: c.autorId == uid,
                  podeApagar: pode && (c.autorId == uid || papel.canEditConfig),
                  podeEditar: pode && c.autorId == uid,
                  onEditar: () => _editarComentario(c, pessoas),
                  onApagar: () => apagarComDesfazer(
                    context,
                    id: c.id,
                    mensagem: 'Comentário apagado.',
                    apagar: () => _repo.apagarComentario(c.id),
                    depois: () {
                      ref.invalidate(comentariosTarefaProvider(_t.id));
                      _atualizarQuadro();
                    },
                    aoFalhar: _erro,
                  ),
                ),
              if (lista.isEmpty && !comentarios.isLoading)
                Text(
                  pode
                      ? 'Ainda sem comentários. Escreve @ e o nome para chamar alguém.'
                      : 'Ainda sem comentários.',
                  style: tt.bodySmall,
                ),
              const SizedBox(height: 12),
              if (podeApagar || pode)
                Wrap(
                  spacing: 8,
                  children: [
                    if (pode)
                      TextButton.icon(
                        icon: const Icon(Icons.archive_outlined),
                        label: const Text('Arquivar'),
                        onPressed: _arquivar,
                      ),
                    if (podeApagar)
                      TextButton.icon(
                        icon: Icon(Icons.delete_outline, color: cs.error),
                        label: Text(
                          'Apagar',
                          style: TextStyle(color: cs.error),
                        ),
                        onPressed: _apagar,
                      ),
                  ],
                ),
            ],
          ),
        ),
        if (pode)
          Material(
            color: cs.surfaceContainer,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  12,
                  8,
                  8,
                  8 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: CampoMencoes(
                        controller: _comentario,
                        focusNode: _comentarioFoco,
                        pessoas: pessoas,
                        hint: 'Comentar… (@ para mencionar)',
                        maxLines: 4,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton.filled(
                      tooltip: 'Enviar',
                      icon: _aEnviar
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      onPressed: _aEnviar
                          ? null
                          : () => _enviarComentario(pessoas),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// "amanhã · sex, 11/10" ou só "20/10/2026" quando o texto curto já é a data.
String _prazoCompleto(DateTime p, DateTime hoje) {
  const dias = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
  final data =
      '${dias[p.weekday - 1]}, ${p.day}/${p.month}'
      '${p.year == hoje.year ? '' : '/${p.year}'}';
  final curto = prazoTexto(p, hoje);
  return curto.contains('/') ? data : '$curto · $data';
}

class _ComentarioLinha extends ConsumerWidget {
  const _ComentarioLinha({
    required this.comentario,
    required this.pessoas,
    required this.autor,
    required this.meu,
    required this.podeApagar,
    required this.podeEditar,
    required this.onEditar,
    required this.onApagar,
  });

  final ComentarioTarefa comentario;
  final List<PessoaEquipa> pessoas;
  final PessoaEquipa? autor;
  final bool meu;
  final bool podeApagar;
  final bool podeEditar;
  final VoidCallback onEditar;
  final VoidCallback onApagar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(ocultosProvider).contains(comentario.id)) {
      return const SizedBox.shrink();
    }
    final tt = Theme.of(context).textTheme;
    final nome =
        autor?.nome ??
        (comentario.autorNome.isEmpty ? 'Alguém' : comentario.autorNome);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AvatarPessoa(PessoaEquipa(comentario.autorId, nome), raio: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        nome,
                        style: tt.labelLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      quandoTexto(comentario.criado, DateTime.now()),
                      style: tt.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                TextoComMencoes(
                  comentario.texto,
                  pessoas: pessoas,
                  style: tt.bodyMedium,
                ),
              ],
            ),
          ),
          if (podeEditar || podeApagar)
            PopupMenuButton<String>(
              tooltip: 'Mais',
              icon: const Icon(Icons.more_horiz, size: 18),
              onSelected: (v) => v == 'editar' ? onEditar() : onApagar(),
              itemBuilder: (_) => [
                if (podeEditar)
                  const PopupMenuItem(value: 'editar', child: Text('Editar')),
                if (podeApagar)
                  const PopupMenuItem(value: 'apagar', child: Text('Apagar')),
              ],
            ),
        ],
      ),
    );
  }
}
