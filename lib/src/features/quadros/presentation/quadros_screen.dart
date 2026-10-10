import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/cores_estado.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/errors/mensagem_amigavel.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/desfazer.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/help_actions.dart';
import '../application/quadros_providers.dart';
import '../data/quadros_repository.dart';
import '../domain/quadro.dart';
import 'quadro_comum.dart';
import 'tarefa_sheet.dart';

/// Tarefas da equipa em quadros, ao estilo Trello: fases lado a lado, cartões
/// que se arrastam de fase em fase, e cada cartão com responsáveis, prazo,
/// etiquetas, lista e comentários com @menções.
class QuadrosScreen extends ConsumerStatefulWidget {
  const QuadrosScreen({super.key, this.abrirTarefaId});

  /// Abre logo esta tarefa (vindo do Início).
  final String? abrirTarefaId;

  @override
  ConsumerState<QuadrosScreen> createState() => _QuadrosScreenState();
}

class _QuadrosScreenState extends ConsumerState<QuadrosScreen> {
  FiltroTarefas _filtro = FiltroTarefas.todas;
  final _busca = TextEditingController();
  bool _aPesquisar = false;
  final _scroll = ScrollController();
  bool _aArrastar = false;
  String? _paraAbrir;

  QuadrosRepository get _repo => ref.read(quadrosRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _paraAbrir = widget.abrirTarefaId;
    if (_paraAbrir != null) unawaited(_prepararAbertura(_paraAbrir!));
  }

  @override
  void didUpdateWidget(QuadrosScreen old) {
    super.didUpdateWidget(old);
    final novo = widget.abrirTarefaId;
    if (novo != null && novo != old.abrirTarefaId) {
      _paraAbrir = novo;
      unawaited(_prepararAbertura(novo));
    }
  }

  @override
  void dispose() {
    _busca.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Vindo do Início: abre o quadro da tarefa (a folha abre quando carregar).
  Future<void> _prepararAbertura(String id) async {
    try {
      final t = await _repo.tarefa(id);
      if (!mounted) return;
      ref.read(quadroEscolhidoProvider.notifier).state = t.quadroId;
    } on Object catch (e) {
      _paraAbrir = null;
      _erro(e);
    }
  }

  void _abrirPendente(DadosQuadro d) {
    final id = _paraAbrir;
    if (id == null) return;
    final t = d.tarefas.where((x) => x.id == id).firstOrNull;
    if (t == null) return;
    _paraAbrir = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        abrirTarefa(context, tarefa: t, colunas: d.colunas, todas: d.tarefas);
      }
    });
  }

  void _erro(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
  }

  Future<void> _fazer(Future<void> Function() f, {String? quadroId}) async {
    try {
      await f();
      ref.invalidate(quadrosProvider);
      if (quadroId != null) ref.invalidate(dadosQuadroProvider(quadroId));
    } on Object catch (e) {
      _erro(e);
    }
  }

  Future<String?> _pedirNome(
    String titulo, {
    String inicial = '',
    String dica = '',
    int max = 80,
  }) async {
    final ctrl = TextEditingController(text: inicial);
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: max,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: dica),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    final n = r?.trim() ?? '';
    return n.isEmpty ? null : n;
  }

  Future<void> _novoQuadro(List<Quadro> quadros) async {
    final nome = await _pedirNome(
      'Novo quadro',
      dica: 'Ex.: Loja, Eventos, Manutenção',
    );
    if (nome == null) return;
    try {
      final q = await _repo.criarQuadro(
        nome,
        ordem: ordemNoFim([for (final x in quadros) x.ordem]),
      );
      ref.read(quadroEscolhidoProvider.notifier).state = q.id;
      ref.invalidate(quadrosProvider);
    } on Object catch (e) {
      _erro(e);
    }
  }

  Future<void> _escolherQuadro(List<Quadro> quadros, String atual) async {
    final pode = ref.read(currentPapelProvider).canEditBusiness;
    final r = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final q in quadros)
              ListTile(
                leading: const Icon(Icons.view_kanban_outlined),
                title: Text(q.nome),
                trailing: q.id == atual ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, q.id),
              ),
            if (pode)
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Novo quadro'),
                onTap: () => Navigator.pop(ctx, '+'),
              ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Quadros arquivados'),
              onTap: () => Navigator.pop(ctx, 'arq'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || r == null) return;
    if (r == '+') return _novoQuadro(quadros);
    if (r == 'arq') return _quadrosArquivados();
    ref.read(quadroEscolhidoProvider.notifier).state = r;
  }

  Future<void> _quadrosArquivados() async {
    final pode = ref.read(currentPapelProvider).canEditBusiness;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final l = ref.watch(quadrosArquivadosProvider).valueOrNull;
          return SafeArea(
            child: l == null
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : l.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Nenhum quadro arquivado.'),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final q in l)
                        ListTile(
                          leading: const Icon(Icons.inventory_2_outlined),
                          title: Text(q.nome),
                          trailing: pode
                              ? TextButton(
                                  onPressed: () async {
                                    await _fazer(
                                      () => _repo.arquivarQuadro(
                                        q.id,
                                        arquivado: false,
                                      ),
                                    );
                                    ref.invalidate(quadrosArquivadosProvider);
                                  },
                                  child: const Text('Recuperar'),
                                )
                              : null,
                        ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Future<void> _tarefasArquivadas(String quadroId, DadosQuadro d) async {
    final pode = ref.read(currentPapelProvider).canEditBusiness;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final l = ref.watch(tarefasArquivadasProvider(quadroId)).valueOrNull;
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.7,
              ),
              child: l == null
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : l.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Nenhuma tarefa arquivada neste quadro.'),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final t in l)
                          ListTile(
                            leading: const Icon(Icons.archive_outlined),
                            title: Text(t.titulo),
                            subtitle: Text(
                              d.colunas
                                      .where((c) => c.id == t.colunaId)
                                      .firstOrNull
                                      ?.nome ??
                                  '',
                            ),
                            trailing: pode
                                ? TextButton(
                                    onPressed: () async {
                                      await _fazer(
                                        () => _repo.arquivarTarefa(
                                          t.id,
                                          arquivada: false,
                                        ),
                                        quadroId: quadroId,
                                      );
                                      ref.invalidate(
                                        tarefasArquivadasProvider(quadroId),
                                      );
                                    },
                                    child: const Text('Recuperar'),
                                  )
                                : null,
                          ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _menuQuadro(String acao, Quadro q, DadosQuadro? d) async {
    switch (acao) {
      case 'renomear':
        final n = await _pedirNome('Nome do quadro', inicial: q.nome);
        if (n != null) await _fazer(() => _repo.renomearQuadro(q.id, n));
      case 'fase':
        await _novaFase(q.id, d);
      case 'arquivadas':
        if (d != null) await _tarefasArquivadas(q.id, d);
      case 'arquivar':
        final messenger = ScaffoldMessenger.of(context);
        await _fazer(() => _repo.arquivarQuadro(q.id, arquivado: true));
        ref.read(quadroEscolhidoProvider.notifier).state = null;
        await mostrarDesfazerEm(
          messenger,
          mensagem: 'Quadro "${q.nome}" arquivado.',
          desfazer: () async {
            await _repo.arquivarQuadro(q.id, arquivado: false);
            ref.invalidate(quadrosProvider);
          },
        );
      case 'apagar':
        ref.read(quadroEscolhidoProvider.notifier).state = null;
        await apagarComDesfazer(
          context,
          id: q.id,
          mensagem: 'Quadro "${q.nome}" apagado, com as suas tarefas.',
          apagar: () => _repo.apagarQuadro(q.id),
          depois: () => ref.invalidate(quadrosProvider),
          aoFalhar: _erro,
        );
    }
  }

  Future<void> _novaFase(String quadroId, DadosQuadro? d) async {
    final n = await _pedirNome(
      'Nova fase',
      dica: 'Ex.: À espera do fornecedor, Para rever',
      max: 60,
    );
    if (n == null) return;
    await _fazer(
      () => _repo.criarColuna(
        quadroId,
        n,
        ordem: ordemNoFim([for (final c in d?.colunas ?? const []) c.ordem]),
      ),
      quadroId: quadroId,
    );
  }

  Future<void> _menuFase(
    String acao,
    ColunaQuadro c,
    DadosQuadro d,
    int nTarefas,
  ) async {
    final i = d.colunas.indexWhere((x) => x.id == c.id);
    switch (acao) {
      case 'renomear':
        final n = await _pedirNome('Nome da fase', inicial: c.nome, max: 60);
        if (n != null) {
          await _fazer(
            () => _repo.editarColuna(c.id, nome: n),
            quadroId: c.quadroId,
          );
        }
      case 'esquerda' || 'direita':
        final j = acao == 'esquerda' ? i - 1 : i + 1;
        if (j < 0 || j >= d.colunas.length) return;
        final outra = d.colunas[j];
        await _fazer(() async {
          await _repo.editarColuna(c.id, ordem: outra.ordem);
          await _repo.editarColuna(outra.id, ordem: c.ordem);
        }, quadroId: c.quadroId);
      case 'feita':
        await _fazer(
          () => _repo.editarColuna(c.id, concluida: !c.concluida),
          quadroId: c.quadroId,
        );
      case 'apagar':
        if (nTarefas > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Esta fase ainda tem tarefas: move-as ou arquiva-as primeiro.',
              ),
            ),
          );
          return;
        }
        await apagarComDesfazer(
          context,
          id: c.id,
          mensagem: 'Fase "${c.nome}" apagada.',
          apagar: () => _repo.apagarColuna(c.id),
          depois: () => ref.invalidate(dadosQuadroProvider(c.quadroId)),
          aoFalhar: _erro,
        );
    }
  }

  /// Larga [t] na fase [colunaId], antes do cartão na posição [antesDe] (como
  /// se vê no ecrã). O cartão muda logo de sítio; o servidor confirma depois.
  Future<void> _largar(
    Tarefa t,
    String colunaId,
    int antesDe,
    List<Tarefa> visiveisDaColuna,
  ) async {
    final ordem = ordemAoLargar(visiveisDaColuna, antesDe, t.id);
    if (t.colunaId == colunaId && ordem == t.ordem) return;
    final pend = ref.read(movimentosPendentesProvider.notifier);
    pend.state = {...pend.state, t.id: (coluna: colunaId, ordem: ordem)};
    try {
      await _repo.mover(t.id, colunaId: colunaId, ordem: ordem);
      ref.invalidate(dadosQuadroProvider(t.quadroId));
      await ref.read(dadosQuadroProvider(t.quadroId).future);
    } on Object catch (e) {
      _erro(e);
    } finally {
      pend.state = {
        for (final e in pend.state.entries)
          if (e.key != t.id) e.key: e.value,
      };
    }
  }

  Future<void> _criarTarefa(
    String quadroId,
    ColunaQuadro c,
    String titulo,
    List<Tarefa> daColuna,
  ) async {
    try {
      await _repo.criarTarefa(
        quadroId: quadroId,
        colunaId: c.id,
        titulo: titulo,
        ordem: ordemNoFim([for (final t in daColuna) t.ordem]),
        autorNome: ref.read(currentUserNameProvider) ?? '',
        // no filtro "Minhas", quem cria fica logo responsável (senão sumia)
        responsaveis: _filtro == FiltroTarefas.minhas
            ? [_repo.utilizadorId]
            : const [],
      );
      ref.invalidate(dadosQuadroProvider(quadroId));
    } on Object catch (e) {
      _erro(e);
    }
  }

  /// Ao arrastar perto das bordas, o quadro anda para o lado.
  void _rolarAoArrastar(Offset global) {
    if (!_aArrastar || !_scroll.hasClients) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final x = box.globalToLocal(global).dx;
    final largura = box.size.width;
    const borda = 56.0;
    double delta = 0;
    if (x < borda) delta = -14;
    if (x > largura - borda) delta = 14;
    if (delta == 0) return;
    final p = _scroll.position;
    _scroll.jumpTo((p.pixels + delta).clamp(0, p.maxScrollExtent));
  }

  @override
  Widget build(BuildContext context) {
    final papel = ref.watch(currentPapelProvider);
    final pode = papel.canEditBusiness;
    final quadrosAsync = ref.watch(quadrosProvider);
    final quadros = quadrosAsync.valueOrNull;
    final escolhido = ref.watch(quadroEscolhidoProvider);
    final quadro = quadros == null || quadros.isEmpty
        ? null
        : quadros.where((q) => q.id == escolhido).firstOrNull ?? quadros.first;
    final dadosAsync = quadro == null
        ? null
        : ref.watch(dadosQuadroProvider(quadro.id));
    final dados = dadosAsync?.valueOrNull;
    if (dados != null) _abrirPendente(dados);
    final uid = _repo.utilizadorId;
    final porLer = dados?.tarefasComMencaoPorLer(uid) ?? const <String>{};
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: quadro == null
            ? const Text('Tarefas')
            : InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _escolherQuadro(quadros!, quadro.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          quadro.nome,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
        actions: [
          if (quadro != null)
            IconButton(
              tooltip: 'Pesquisar',
              icon: Icon(_aPesquisar ? Icons.search_off : Icons.search),
              onPressed: () => setState(() {
                _aPesquisar = !_aPesquisar;
                if (!_aPesquisar) _busca.clear();
              }),
            ),
          const HelpActions(topic: HelpTopic.tarefas),
          if (quadro != null)
            PopupMenuButton<String>(
              tooltip: 'Opções do quadro',
              onSelected: (a) => _menuQuadro(a, quadro, dados),
              itemBuilder: (_) => [
                if (pode) ...[
                  const PopupMenuItem(value: 'fase', child: Text('Nova fase')),
                  const PopupMenuItem(
                    value: 'renomear',
                    child: Text('Mudar o nome do quadro'),
                  ),
                ],
                const PopupMenuItem(
                  value: 'arquivadas',
                  child: Text('Tarefas arquivadas'),
                ),
                if (pode)
                  const PopupMenuItem(
                    value: 'arquivar',
                    child: Text('Arquivar o quadro'),
                  ),
                if (pode && (papel.canEditConfig || quadro.autorId == uid))
                  const PopupMenuItem(
                    value: 'apagar',
                    child: Text('Apagar o quadro'),
                  ),
              ],
            ),
        ],
      ),
      body: quadrosAsync.hasError && quadros == null
          ? _Erro(
              erro: quadrosAsync.error!,
              onRetry: () => ref.invalidate(quadrosProvider),
            )
          : quadros == null
          ? const Center(child: CircularProgressIndicator())
          : quadro == null
          ? EmptyState(
              icon: Icons.view_kanban_outlined,
              titulo: 'Ainda não há quadros',
              mensagem:
                  'Um quadro junta as tarefas de um assunto (a loja, um evento, '
                  'as obras…) em fases: A fazer → Em curso → Feito.',
              acao: pode
                  ? FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Criar o primeiro quadro'),
                      onPressed: () => _novoQuadro(quadros),
                    )
                  : null,
            )
          : Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: _BarraFiltros(
                    filtro: _filtro,
                    nMencoes: porLer.length,
                    nAtrasadas: dados == null
                        ? 0
                        : filtrarTarefas(
                            dados.tarefas,
                            filtro: FiltroTarefas.atrasadas,
                            uid: uid,
                            colunasFeitas: dados.colunasFeitas,
                          ).length,
                    onFiltro: (f) => setState(() => _filtro = f),
                  ),
                ),
                if (_aPesquisar)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: TextField(
                      controller: _busca,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Título, etiqueta ou pessoa',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                Expanded(
                  child: dadosAsync!.hasError && dados == null
                      ? _Erro(
                          erro: dadosAsync.error!,
                          onRetry: () =>
                              ref.invalidate(dadosQuadroProvider(quadro.id)),
                        )
                      : dados == null
                      ? const Center(child: CircularProgressIndicator())
                      : Listener(
                          onPointerMove: (e) => _rolarAoArrastar(e.position),
                          child: _Quadro(
                            quadro: quadro,
                            dados: dados,
                            pode: pode,
                            filtro: _filtro,
                            busca: _busca.text,
                            uid: uid,
                            porLer: porLer,
                            scroll: _scroll,
                            onArrastar: (v) => setState(() => _aArrastar = v),
                            onLargar: _largar,
                            onCriar: (c, titulo, daColuna) =>
                                _criarTarefa(quadro.id, c, titulo, daColuna),
                            onMenuFase: (a, c, n) => _menuFase(a, c, dados, n),
                            onNovaFase: () => _novaFase(quadro.id, dados),
                          ),
                        ),
                ),
                if (dadosAsync.isRefreshing)
                  LinearProgressIndicator(minHeight: 2, color: cs.primary),
              ],
            ),
    );
  }
}

class _Erro extends StatelessWidget {
  const _Erro({required this.erro, required this.onRetry});

  final Object erro;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 40),
          const SizedBox(height: 8),
          Text(mensagemAmigavel(erro), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Tentar de novo'),
          ),
        ],
      ),
    ),
  );
}

class _BarraFiltros extends StatelessWidget {
  const _BarraFiltros({
    required this.filtro,
    required this.nMencoes,
    required this.nAtrasadas,
    required this.onFiltro,
  });

  final FiltroTarefas filtro;
  final int nMencoes;
  final int nAtrasadas;
  final ValueChanged<FiltroTarefas> onFiltro;

  @override
  Widget build(BuildContext context) {
    String rotulo(FiltroTarefas f) => switch (f) {
      FiltroTarefas.mencoes when nMencoes > 0 => '${f.label} ($nMencoes)',
      FiltroTarefas.atrasadas when nAtrasadas > 0 => '${f.label} ($nAtrasadas)',
      _ => f.label,
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final f in FiltroTarefas.values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(rotulo(f)),
                selected: filtro == f,
                onSelected: (_) => onFiltro(f),
              ),
            ),
        ],
      ),
    );
  }
}

typedef _AoLargar =
    Future<void> Function(
      Tarefa t,
      String colunaId,
      int antesDe,
      List<Tarefa> visiveisDaColuna,
    );

class _Quadro extends ConsumerWidget {
  const _Quadro({
    required this.quadro,
    required this.dados,
    required this.pode,
    required this.filtro,
    required this.busca,
    required this.uid,
    required this.porLer,
    required this.scroll,
    required this.onArrastar,
    required this.onLargar,
    required this.onCriar,
    required this.onMenuFase,
    required this.onNovaFase,
  });

  final Quadro quadro;
  final DadosQuadro dados;
  final bool pode;
  final FiltroTarefas filtro;
  final String busca;
  final String uid;
  final Set<String> porLer;
  final ScrollController scroll;
  final ValueChanged<bool> onArrastar;
  final _AoLargar onLargar;
  final void Function(ColunaQuadro c, String titulo, List<Tarefa> daColuna)
  onCriar;
  final void Function(String acao, ColunaQuadro c, int nTarefas) onMenuFase;
  final VoidCallback onNovaFase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ocultos = ref.watch(ocultosProvider);
    final pendentes = ref.watch(movimentosPendentesProvider);
    final pessoas = ref.watch(pessoasEquipaProvider);
    final nomes = {for (final p in pessoas) p.id: p.nome};
    final todas = [
      for (final t in comMovimentos(dados.tarefas, pendentes))
        if (!ocultos.contains(t.id)) t,
    ];
    final visiveis = filtrarTarefas(
      todas,
      filtro: filtro,
      uid: uid,
      colunasFeitas: dados.colunasFeitas,
      comMencaoPorLer: porLer,
      nomes: nomes,
      busca: busca,
    );
    final nComentarios = dados.nComentarios;
    final colunas = [
      for (final c in dados.colunas)
        if (!ocultos.contains(c.id)) c,
    ];

    return LayoutBuilder(
      builder: (context, box) {
        final largura = box.maxWidth < 360
            ? box.maxWidth - 40
            : (box.maxWidth * 0.86).clamp(260.0, 300.0);
        return ListView(
          controller: scroll,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: [
            for (var i = 0; i < colunas.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _Coluna(
                  largura: largura,
                  coluna: colunas[i],
                  primeira: i == 0,
                  ultima: i == colunas.length - 1,
                  tarefas: tarefasDaColuna(visiveis, colunas[i].id),
                  nTotal: tarefasDaColuna(todas, colunas[i].id).length,
                  todas: todas,
                  colunas: colunas,
                  pessoas: pessoas,
                  nComentarios: nComentarios,
                  porLer: porLer,
                  pode: pode,
                  onArrastar: onArrastar,
                  onLargar: onLargar,
                  onCriar: onCriar,
                  onMenu: onMenuFase,
                ),
              ),
            if (pode)
              SizedBox(
                width: largura * 0.8,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Nova fase'),
                    onPressed: onNovaFase,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Coluna extends StatefulWidget {
  const _Coluna({
    required this.largura,
    required this.coluna,
    required this.primeira,
    required this.ultima,
    required this.tarefas,
    required this.nTotal,
    required this.todas,
    required this.colunas,
    required this.pessoas,
    required this.nComentarios,
    required this.porLer,
    required this.pode,
    required this.onArrastar,
    required this.onLargar,
    required this.onCriar,
    required this.onMenu,
  });

  final double largura;
  final ColunaQuadro coluna;
  final bool primeira;
  final bool ultima;

  /// As visíveis (com o filtro/pesquisa), pela ordem.
  final List<Tarefa> tarefas;
  final int nTotal;
  final List<Tarefa> todas;
  final List<ColunaQuadro> colunas;
  final List<PessoaEquipa> pessoas;
  final Map<String, int> nComentarios;
  final Set<String> porLer;
  final bool pode;
  final ValueChanged<bool> onArrastar;
  final _AoLargar onLargar;
  final void Function(ColunaQuadro c, String titulo, List<Tarefa> daColuna)
  onCriar;
  final void Function(String acao, ColunaQuadro c, int nTarefas) onMenu;

  @override
  State<_Coluna> createState() => _ColunaState();
}

class _ColunaState extends State<_Coluna> {
  bool _aAdicionar = false;
  final _novo = TextEditingController();
  final _foco = FocusNode();

  @override
  void dispose() {
    _novo.dispose();
    _foco.dispose();
    super.dispose();
  }

  void _criar() {
    final t = _novo.text.trim();
    if (t.isEmpty) {
      setState(() => _aAdicionar = false);
      return;
    }
    _novo.clear();
    widget.onCriar(widget.coluna, t, widget.tarefas);
    // fica aberto para escrever a seguinte (como no Trello)
    _foco.requestFocus();
  }

  bool get _desktop => switch (defaultTargetPlatform) {
    TargetPlatform.windows ||
    TargetPlatform.macOS ||
    TargetPlatform.linux => true,
    _ => false,
  };

  Widget _arrastavel(Tarefa t, Widget cartao) {
    if (!widget.pode) return cartao;
    final fantasma = Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(width: widget.largura - 16, child: cartao),
    );
    final aqui = Opacity(opacity: 0.35, child: cartao);
    void inicio() => widget.onArrastar(true);
    void fim() => widget.onArrastar(false);
    // no computador arrasta-se logo; no telemóvel é preciso manter o dedo
    // (senão não dava para rolar a lista)
    return _desktop
        ? Draggable<Tarefa>(
            data: t,
            feedback: fantasma,
            childWhenDragging: aqui,
            onDragStarted: inicio,
            onDragEnd: (_) => fim(),
            onDraggableCanceled: (_, __) => fim(),
            child: cartao,
          )
        : LongPressDraggable<Tarefa>(
            data: t,
            feedback: fantasma,
            childWhenDragging: aqui,
            onDragStarted: inicio,
            onDragEnd: (_) => fim(),
            onDraggableCanceled: (_, __) => fim(),
            child: cartao,
          );
  }

  Widget _alvo(int antesDe, Widget child, {String? proprio}) =>
      DragTarget<Tarefa>(
        onWillAcceptWithDetails: (d) => widget.pode && d.data.id != proprio,
        onAcceptWithDetails: (d) =>
            widget.onLargar(d.data, widget.coluna.id, antesDe, widget.tarefas),
        builder: (context, candidatos, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              height: candidatos.isEmpty ? 0 : 52,
              margin: EdgeInsets.only(bottom: candidatos.isEmpty ? 0 : 6),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: candidatos.isEmpty
                    ? null
                    : Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.5,
                      ),
              ),
            ),
            child,
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final c = widget.coluna;
    final n = widget.tarefas.length;

    return Container(
      width: widget.largura,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 0, 2),
            child: Row(
              children: [
                if (c.concluida) ...[
                  Icon(Icons.check_circle, size: 18, color: cs.sucesso),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    c.nome,
                    style: tt.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  n == widget.nTotal ? '$n' : '$n de ${widget.nTotal}',
                  style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                if (widget.pode)
                  PopupMenuButton<String>(
                    tooltip: 'Opções da fase',
                    icon: const Icon(Icons.more_horiz),
                    onSelected: (a) => widget.onMenu(a, c, widget.nTotal),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'renomear',
                        child: Text('Mudar o nome'),
                      ),
                      if (!widget.primeira)
                        const PopupMenuItem(
                          value: 'esquerda',
                          child: Text('Mover para a esquerda'),
                        ),
                      if (!widget.ultima)
                        const PopupMenuItem(
                          value: 'direita',
                          child: Text('Mover para a direita'),
                        ),
                      PopupMenuItem(
                        value: 'feita',
                        child: Text(
                          c.concluida
                              ? 'Deixar de contar como feito'
                              : 'Tarefas aqui contam como feitas',
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'apagar',
                        child: Text('Apagar a fase'),
                      ),
                    ],
                  )
                else
                  const SizedBox(width: 12),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
              children: [
                for (var i = 0; i < n; i++)
                  _alvo(
                    i,
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _arrastavel(
                        widget.tarefas[i],
                        _Cartao(
                          tarefa: widget.tarefas[i],
                          feita: c.concluida,
                          pessoas: widget.pessoas,
                          nComentarios:
                              widget.nComentarios[widget.tarefas[i].id] ?? 0,
                          mencaoPorLer: widget.porLer.contains(
                            widget.tarefas[i].id,
                          ),
                          onTap: () => abrirTarefa(
                            context,
                            tarefa: widget.tarefas[i],
                            colunas: widget.colunas,
                            todas: widget.todas,
                          ),
                        ),
                      ),
                    ),
                    proprio: widget.tarefas[i].id,
                  ),
                // largar no fim (também numa fase vazia)
                _alvo(n, SizedBox(height: n == 0 ? 56 : 24)),
              ],
            ),
          ),
          if (widget.pode)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: _aAdicionar
                  ? TextField(
                      controller: _novo,
                      focusNode: _foco,
                      autofocus: true,
                      maxLength: 200,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Título e Enter',
                        counterText: '',
                        isDense: true,
                        suffixIcon: IconButton(
                          tooltip: 'Fechar',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() {
                            _novo.clear();
                            _aAdicionar = false;
                          }),
                        ),
                      ),
                      onSubmitted: (_) => _criar(),
                    )
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Adicionar tarefa'),
                        onPressed: () => setState(() => _aAdicionar = true),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}

class _Cartao extends StatelessWidget {
  const _Cartao({
    required this.tarefa,
    required this.feita,
    required this.pessoas,
    required this.nComentarios,
    required this.mencaoPorLer,
    required this.onTap,
  });

  final Tarefa tarefa;
  final bool feita;
  final List<PessoaEquipa> pessoas;
  final int nComentarios;
  final bool mencaoPorLer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final t = tarefa;
    final hoje = DateTime.now();
    final atrasada = t.atrasada(hoje, feita: feita);
    final paraHoje = t.paraHoje(hoje, feita: feita);
    final responsaveis = [
      for (final r in t.responsaveis)
        pessoas.where((p) => p.id == r).firstOrNull ?? PessoaEquipa(r, '?'),
    ];
    final corPrazo = feita
        ? cs.sucesso
        : atrasada
        ? cs.error
        : paraHoje
        ? cs.aviso
        : cs.onSurfaceVariant;
    final pequeno = tt.labelSmall?.copyWith(color: cs.onSurfaceVariant);

    final rodape = <Widget>[
      if (t.prazo != null)
        _Info(
          icone: feita ? Icons.check_circle_outline : Icons.schedule,
          texto: prazoTexto(t.prazo!, hoje),
          cor: corPrazo,
          negrito: atrasada || paraHoje,
        ),
      if (t.temChecklist)
        _Info(
          icone: Icons.checklist,
          texto: '${t.checklistFeitos}/${t.checklist.length}',
          cor: t.checklistFeitos == t.checklist.length
              ? cs.sucesso
              : cs.onSurfaceVariant,
        ),
      if (t.descricao.trim().isNotEmpty)
        Icon(Icons.notes, size: 15, color: cs.onSurfaceVariant),
      if (nComentarios > 0)
        _Info(
          icone: Icons.chat_bubble_outline,
          texto: '$nComentarios',
          cor: cs.onSurfaceVariant,
        ),
      if (mencaoPorLer)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '@',
            style: tt.labelSmall?.copyWith(
              color: cs.onPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
    ];

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: atrasada
            ? BorderSide(color: cs.error.withValues(alpha: 0.6))
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (t.etiquetas.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final e in t.etiquetas.take(4))
                        EtiquetaPilula(e, pequena: true),
                      if (t.etiquetas.length > 4)
                        Text('+${t.etiquetas.length - 4}', style: pequeno),
                    ],
                  ),
                ),
              Text(
                t.titulo,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: tt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  decoration: feita ? TextDecoration.lineThrough : null,
                  color: feita ? cs.onSurfaceVariant : null,
                ),
              ),
              if (rodape.isNotEmpty || responsaveis.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: rodape,
                      ),
                    ),
                    AvataresResponsaveis(responsaveis),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({
    required this.icone,
    required this.texto,
    required this.cor,
    this.negrito = false,
  });

  final IconData icone;
  final String texto;
  final Color cor;
  final bool negrito;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icone, size: 15, color: cor),
      const SizedBox(width: 3),
      Text(
        texto,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: cor,
          fontWeight: negrito ? FontWeight.w700 : null,
        ),
      ),
    ],
  );
}
