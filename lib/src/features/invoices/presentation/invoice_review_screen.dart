import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router.dart';
import '../../../core/formatting/dates.dart';
import '../../../core/formatting/quantities.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/help_actions.dart';
import '../../ingredients/application/ingredients_providers.dart';
import '../../ingredients/data/ingredient_repository.dart';
import '../../ingredients/domain/ingredient.dart';
import '../application/invoice_providers.dart';
import '../data/invoice_repository.dart';
import '../domain/fatura.dart';
import '../domain/match_ingrediente.dart';

class InvoiceReviewScreen extends ConsumerWidget {
  const InvoiceReviewScreen({super.key, required this.faturaId});
  final String faturaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faturaAsync = ref.watch(faturaProvider(faturaId));
    final ingsAsync = ref.watch(ingredientsListProvider(false));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.invoices),
        ),
        title: const Text('Rever fatura'),
        actions: const [HelpActions(topic: HelpTopic.faturaRevisao)],
      ),
      body: AsyncValueView<Fatura>(
        value: faturaAsync,
        onRetry: () => ref.invalidate(faturaProvider(faturaId)),
        data: (fatura) {
          if (fatura.estado == FaturaEstado.erro) {
            return _Erro(fatura: fatura);
          }
          if (fatura.linhasIa.isEmpty) {
            return _SemLinhas(fatura: fatura);
          }
          return ingsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (ings) => _Revisao(fatura: fatura, ingredientes: ings),
          );
        },
      ),
    );
  }
}

class _Erro extends ConsumerStatefulWidget {
  const _Erro({required this.fatura});
  final Fatura fatura;

  @override
  ConsumerState<_Erro> createState() => _ErroState();
}

class _ErroState extends ConsumerState<_Erro> {
  bool _busy = false;

  Future<void> _tentarDeNovo() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final r = await ref
          .read(invoiceActionsProvider)
          .tentarDeNovo(widget.fatura);
      if (r.ids.length > 1) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '${r.ids.length} faturas detetadas neste ficheiro. Revê-as na lista.',
            ),
          ),
        );
        if (mounted && context.canPop()) context.pop();
      }
    } on Object {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Ainda não foi possível analisar. Tenta daqui a uns minutos.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fatura = widget.fatura;
    final duplicada = fatura.duplicadaDe.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            duplicada ? Icons.copy_all_outlined : Icons.error_outline,
            size: 40,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(
            duplicada ? fatura.erroIa : 'A análise falhou: ${fatura.erroIa}',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            duplicada
                ? 'Esta fatura já tinha sido carregada. Podes apagá-la.'
                : 'Se a IA estava sobrecarregada, tenta de novo daqui a uns '
                      'minutos. Se persistir, verifica a configuração da IA no '
                      'servidor (fornecedor e chave) ou usa uma foto mais nítida.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (duplicada)
                OutlinedButton.icon(
                  onPressed: () => context.pushReplacement(
                    '${Routes.invoices}/${fatura.duplicadaDe}',
                  ),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Abrir a original'),
                ),
              if (!duplicada)
                FilledButton.icon(
                  onPressed: _busy ? null : _tentarDeNovo,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: const Text('Tentar de novo'),
                ),
              OutlinedButton.icon(
                onPressed: () async {
                  final ok = await confirmDialog(
                    context,
                    titulo: 'Apagar esta fatura?',
                    mensagem: 'Remove o registo e o ficheiro carregado.',
                    confirmar: 'Apagar',
                    destrutivo: true,
                  );
                  if (!ok) return;
                  await ref.read(invoiceActionsProvider).apagar(fatura.id);
                  if (context.mounted && context.canPop()) context.pop();
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Apagar fatura'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SemLinhas extends ConsumerWidget {
  const _SemLinhas({required this.fatura});
  final Fatura fatura;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 40,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          const Text(
            'A IA não devolveu nenhuma linha desta fatura. Se acabaste de a '
            'criar, aguarda uns segundos e recarrega; se a foto está tremida '
            'ou cortada, apaga e volta a carregar uma melhor.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () async {
              final ok = await confirmDialog(
                context,
                titulo: 'Apagar esta fatura?',
                mensagem:
                    'Remove o registo e o ficheiro carregado. '
                    'Fica registo em "Faturas apagadas".',
                confirmar: 'Apagar',
                destrutivo: true,
              );
              if (!ok) return;
              await ref.read(invoiceActionsProvider).apagar(fatura.id);
              if (context.mounted && context.canPop()) context.pop();
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Apagar fatura'),
          ),
        ],
      ),
    );
  }
}

String _normNome(String s) =>
    s.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

class _LinhaState {
  _LinhaState(this.ia, Ingrediente? match, bool isLista)
    : ingrediente = match,
      qtd = TextEditingController(
        text: ia.quantidadeG > 0 ? ia.quantidadeG.toStringAsFixed(0) : '',
      ),
      preco = TextEditingController(
        text: (ia.precoUnitario ?? 0) > 0
            ? ia.precoUnitario!.toStringAsFixed(2)
            : '',
      ),
      emb = TextEditingController(
        text: (ia.embalagemG ?? 0) > 0
            ? ia.embalagemG!.toStringAsFixed(0)
            : (match != null && match.gramasEmbalagem > 0
                  ? match.gramasEmbalagem.toStringAsFixed(0)
                  : ''),
      ),
      nome = TextEditingController(text: ia.descricao),
      acao = match == null
          ? AcaoFatura.ignorar
          : (isLista ? AcaoFatura.preco : AcaoFatura.ambos);

  final FaturaLinhaIa ia;

  /// Ingrediente existente ligado a esta linha (null se vai criar um novo).
  Ingrediente? ingrediente;

  /// Criar um ingrediente novo (com o nome do campo [nome]).
  bool criarNovo = false;

  /// Renomear o [ingrediente] ligado para [nome] — propaga a todas as receitas
  /// e fichas (que referenciam o ingrediente por id).
  bool renomear = false;

  final TextEditingController qtd;
  final TextEditingController preco;
  final TextEditingController emb;

  /// Nome para o ingrediente novo / para o renomear.
  final TextEditingController nome;

  AcaoFatura acao;

  double _n(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.').trim()) ?? 0;

  double get precoV => _n(preco);
  double get embV => _n(emb);

  /// A descrição da fatura difere do nome do ingrediente ligado?
  bool get nomeDiferente =>
      ingrediente != null &&
      _normNome(ingrediente!.nome) != _normNome(ia.descricao);

  bool get temAlvo => ingrediente != null || criarNovo;

  LinhaAAplicar toAplicar(String? ingredienteId) => (
    ingredienteId: ingredienteId,
    descricaoFatura: ia.descricao,
    quantidadeG: _n(qtd),
    precoUnitario: _n(preco),
    totalLinha: ia.total ?? 0,
    embalagemG: _n(emb),
    acao: acao,
  );
}

class _Revisao extends ConsumerStatefulWidget {
  const _Revisao({required this.fatura, required this.ingredientes});
  final Fatura fatura;
  final List<Ingrediente> ingredientes;

  @override
  ConsumerState<_Revisao> createState() => _RevisaoState();
}

class _RevisaoState extends ConsumerState<_Revisao> {
  late final List<_LinhaState> _linhas;
  bool _busy = false;
  bool _verFatura = true;

  bool get _isLista => widget.fatura.tipo == FaturaTipo.listaPrecos;

  @override
  void initState() {
    super.initState();
    _linhas = [
      for (final ia in widget.fatura.linhasIa)
        _LinhaState(
          ia,
          melhorMatch(ia.descricao, widget.ingredientes),
          _isLista,
        ),
    ];
  }

  Future<void> _escolherIngrediente(_LinhaState l) async {
    final r = await showModalBottomSheet<_EscolhaIngrediente>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _IngredientePicker(
        ingredientes: widget.ingredientes,
        descricaoFatura: l.ia.descricao,
      ),
    );
    if (r == null) return;
    setState(() {
      if (l.acao == AcaoFatura.ignorar) {
        l.acao = _isLista ? AcaoFatura.preco : AcaoFatura.ambos;
      }
      switch (r) {
        case _EscolhaExistente(:final ing):
          l.ingrediente = ing;
          l.criarNovo = false;
          l.renomear = false;
          if (l.emb.text.trim().isEmpty && ing.gramasEmbalagem > 0) {
            l.emb.text = ing.gramasEmbalagem.toStringAsFixed(0);
          }
        case _EscolhaNovo():
          l.ingrediente = null;
          l.criarNovo = true;
          l.renomear = false;
          l.nome.text = l.ia.descricao;
      }
    });
  }

  Future<void> _aplicar() async {
    final aAplicar = _linhas
        .where((l) => l.acao != AcaoFatura.ignorar)
        .toList();
    if (aAplicar.any((l) => !l.temAlvo)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Há linhas sem ingrediente. Liga, cria um novo, ou põe '
            'em Ignorar.',
          ),
        ),
      );
      return;
    }
    if (aAplicar.any(
      (l) => (l.criarNovo || l.renomear) && l.nome.text.trim().isEmpty,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dá um nome ao ingrediente a criar/renomear.'),
        ),
      );
      return;
    }
    final novos = aAplicar.where((l) => l.criarNovo).length;
    final renomes = aAplicar.where((l) => l.renomear).length;

    // Aviso: preços que não vão mudar porque a fatura é mais antiga do que a
    // última atualização de preço do ingrediente (o servidor também garante).
    final dFatura = DateTime.tryParse(
      widget.fatura.dataFatura.isNotEmpty
          ? widget.fatura.dataFatura
          : widget.fatura.created,
    );
    var maisAntigos = 0;
    if (dFatura != null) {
      final diaFatura = DateTime(dFatura.year, dFatura.month, dFatura.day);
      for (final l in aAplicar) {
        if (l.acao != AcaoFatura.preco && l.acao != AcaoFatura.ambos) continue;
        final at = l.ingrediente?.precoAtualizadoEm;
        if (at != null &&
            diaFatura.isBefore(DateTime(at.year, at.month, at.day))) {
          maisAntigos++;
        }
      }
    }

    final ok = await confirmDialog(
      context,
      titulo: 'Aplicar ${aAplicar.length} linha(s)?',
      mensagem: [
        'Atualiza os preços dos ingredientes escolhidos e dá entrada no '
            'inventário das quantidades marcadas.',
        if (maisAntigos > 0)
          'Atenção: $maisAntigos preço(s) NÃO vão mudar — esta fatura é mais '
              'antiga do que a última atualização desse ingrediente.',
        if (novos > 0) 'Cria $novos ingrediente(s) novo(s).',
        if (renomes > 0)
          'Renomeia $renomes ingrediente(s) — muda em todas as receitas e '
              'fichas que o usam.',
        'A fatura fica confirmada.',
      ].join(' '),
      confirmar: 'Aplicar',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(ingredientRepositoryProvider);
      final forn = widget.fatura.fornecedor.trim();
      final ids = <_LinhaState, String?>{};
      for (final l in _linhas) {
        if (l.acao == AcaoFatura.ignorar) {
          ids[l] = null;
          continue;
        }
        if (l.criarNovo) {
          final novo = await repo.create(
            IngredienteInput(
              nome: l.nome.text.trim(),
              fornecedor: forn,
              preco: l.precoV,
              gramasEmbalagem: l.embV,
              origem: OrigemIngrediente.comprado,
            ),
          );
          ids[l] = novo.id;
        } else if (l.renomear && l.ingrediente != null) {
          final ing = l.ingrediente!;
          await repo.update(
            ing.id,
            IngredienteInput(
              nome: l.nome.text.trim(),
              caracteristica: ing.caracteristica,
              marca: ing.marca,
              fornecedor: forn.isNotEmpty ? forn : ing.fornecedor,
              preco: ing.preco,
              gramasEmbalagem: ing.gramasEmbalagem,
              disponivel: ing.disponivel,
              origem: ing.origem,
            ),
          );
          ids[l] = ing.id;
        } else {
          ids[l] = l.ingrediente?.id;
        }
      }

      final res = await ref
          .read(invoiceActionsProvider)
          .aplicar(
            widget.fatura.id,
            _linhas.map((l) => l.toAplicar(ids[l])).toList(),
          );
      ref.invalidate(ingredientsListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            [
              '${res.precos} preço(s), ${res.movimentos} entrada(s) de stock',
              if (res.precosIgnorados > 0)
                '${res.precosIgnorados} preço(s) mantidos (fatura mais antiga)',
              if (novos > 0) '$novos novo(s)',
              if (renomes > 0) '$renomes renomeado(s)',
            ].join(' · '),
          ),
        ),
      );
      if (context.canPop()) context.pop();
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _abrirZoom(String url) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            InteractiveViewer(
              maxScale: 6,
              child: Center(child: Image.network(url)),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Pré-visualização grande da fatura, para conferir os dados ao lado (ecrã
  /// largo) ou por cima (telemóvel) das linhas.
  Widget _previewFatura(Fatura f, {required bool wide}) {
    _urlFuture ??= ref.read(invoiceRepositoryProvider).ficheiroUrlSeguro(f);
    return FutureBuilder<String>(
      future: _urlFuture,
      builder: (ctx, snap) {
        if (snap.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Não foi possível abrir o ficheiro da fatura.'),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }
        return _previewComUrl(f, snap.data!, wide: wide);
      },
    );
  }

  Future<String>? _urlFuture;

  Widget _previewComUrl(Fatura f, String url, {required bool wide}) {
    final cs = Theme.of(context).colorScheme;

    if (f.ficheiroEhPdf) {
      return Container(
        width: double.infinity,
        height: wide ? null : 150,
        color: cs.surfaceContainerHighest,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.picture_as_pdf_outlined, size: 40, color: cs.primary),
            const SizedBox(height: 8),
            const Text('Fatura em PDF'),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () async {
                final u = await ref
                    .read(invoiceRepositoryProvider)
                    .ficheiroUrlSeguro(f);
                await launchUrl(
                  Uri.parse(u),
                  mode: LaunchMode.externalApplication,
                );
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Abrir PDF'),
            ),
          ],
        ),
      );
    }

    final img = Image.network(
      url,
      fit: BoxFit.contain,
      loadingBuilder: (ctx, child, prog) => prog == null
          ? child
          : const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
      errorBuilder: (ctx, e, s) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Não foi possível carregar a imagem da fatura.'),
        ),
      ),
    );

    return Container(
      width: double.infinity,
      height: wide
          ? null
          : math.min(MediaQuery.of(context).size.height * 0.36, 380),
      color: cs.surfaceContainerHighest,
      child: wide
          ? InteractiveViewer(maxScale: 6, child: img)
          : Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => _abrirZoom(url),
                    child: img,
                  ),
                ),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(
                        Icons.zoom_out_map,
                        color: Colors.white,
                        size: 20,
                      ),
                      tooltip: 'Ampliar',
                      onPressed: () => _abrirZoom(url),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _toggleBar(Fatura f) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: InkWell(
      onTap: () => setState(() => _verFatura = !_verFatura),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(_verFatura ? Icons.expand_less : Icons.expand_more, size: 20),
            const SizedBox(width: 6),
            Text(_verFatura ? 'Ocultar fatura' : 'Ver fatura'),
            const Spacer(),
            if (!f.ficheiroEhPdf && _verFatura)
              Text(
                'toca para ampliar',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    ),
  );

  Widget _cabecalho(Fatura f) => Card(
    child: ListTile(
      leading: Icon(
        f.ficheiroEhPdf
            ? Icons.picture_as_pdf_outlined
            : Icons.receipt_long_outlined,
      ),
      title: Text(f.fornecedor.isEmpty ? 'Fornecedor?' : f.fornecedor),
      subtitle: Text(
        [
          f.tipo.label,
          if (f.numero.isNotEmpty) 'nº ${f.numero}',
          if (f.dataFatura.isNotEmpty) formatDateShort(f.dataFatura),
          if (f.total > 0) 'total ${f.total.toStringAsFixed(2)}',
        ].join(' · '),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final f = widget.fatura;
    final lista = ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: [
        _cabecalho(f),
        const SizedBox(height: 8),
        Text(
          'Linhas lidas pela IA — confirma cada uma',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        for (final l in _linhas)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 3),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.ia.descricao,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _escolherIngrediente(l),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Ingrediente',
                        isDense: true,
                        suffixIcon: const Icon(Icons.arrow_drop_down),
                        helperText: l.criarNovo
                            ? 'Vai criar um ingrediente novo'
                            : (l.renomear
                                  ? 'Vai renomear o ingrediente ligado'
                                  : null),
                      ),
                      child: Text(
                        l.criarNovo
                            ? 'Novo ingrediente'
                            : (l.ingrediente?.nome ?? 'Escolher ingrediente…'),
                        style: TextStyle(
                          color: !l.temAlvo
                              ? Theme.of(context).colorScheme.error
                              : null,
                        ),
                      ),
                    ),
                  ),
                  if (l.criarNovo || l.renomear) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: l.nome,
                      decoration: InputDecoration(
                        labelText: l.criarNovo
                            ? 'Nome do ingrediente novo'
                            : 'Novo nome do ingrediente',
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                  if (l.ingrediente != null && l.nomeDiferente)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: CheckboxListTile(
                        value: l.renomear,
                        onChanged: (v) => setState(() {
                          l.renomear = v ?? false;
                          if (l.renomear) l.nome.text = l.ia.descricao;
                        }),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          'Passar «${l.ingrediente!.nome}» a '
                          'chamar-se «${l.ia.descricao}»',
                        ),
                        subtitle: const Text(
                          'muda em todas as receitas e fichas que o usam',
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (!_isLista) ...[
                        Expanded(
                          child: TextField(
                            controller: l.qtd,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Comprado',
                              suffixText: 'g',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: TextField(
                          controller: l.preco,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Preço embalagem',
                            prefixText: '€ ',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: l.emb,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Embalagem',
                            suffixText: 'g',
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<AcaoFatura>(
                    // `l.acao` também muda por fora (ex.: ao escolher
                    // ingrediente numa linha "ignorar" — linha 288); a
                    // key força um remount para o `initialValue` refletir
                    // essa mudança (deixou de ser um campo controlado).
                    key: ValueKey('${identityHashCode(l)}_${l.acao.name}'),
                    initialValue: l.acao,
                    decoration: const InputDecoration(
                      labelText: 'Ação',
                      isDense: true,
                    ),
                    items: [
                      for (final a in AcaoFatura.values)
                        if (!_isLista ||
                            a == AcaoFatura.preco ||
                            a == AcaoFatura.ignorar)
                          DropdownMenuItem(value: a, child: Text(a.label)),
                    ],
                    onChanged: (a) =>
                        setState(() => l.acao = a ?? AcaoFatura.ignorar),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _aplicar,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: const Text('Aplicar aos ingredientes'),
        ),
      ],
    );

    if (!f.temFicheiro) return lista;

    final wide = MediaQuery.of(context).size.width >= 820;
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 380, child: _previewFatura(f, wide: true)),
          const VerticalDivider(width: 1),
          Expanded(child: lista),
        ],
      );
    }
    return Column(
      children: [
        if (_verFatura) _previewFatura(f, wide: false),
        _toggleBar(f),
        Expanded(child: lista),
      ],
    );
  }
}

/// Resultado do `_IngredientePicker`: ligar a um existente ou criar um novo.
sealed class _EscolhaIngrediente {
  const _EscolhaIngrediente();
}

class _EscolhaExistente extends _EscolhaIngrediente {
  const _EscolhaExistente(this.ing);
  final Ingrediente ing;
}

class _EscolhaNovo extends _EscolhaIngrediente {
  const _EscolhaNovo();
}

class _IngredientePicker extends StatefulWidget {
  const _IngredientePicker({
    required this.ingredientes,
    required this.descricaoFatura,
  });
  final List<Ingrediente> ingredientes;
  final String descricaoFatura;

  @override
  State<_IngredientePicker> createState() => _IngredientePickerState();
}

class _IngredientePickerState extends State<_IngredientePicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final itens = widget.ingredientes
        .where(
          (i) => _q.isEmpty || i.nome.toLowerCase().contains(_q.toLowerCase()),
        )
        .toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Procurar ingrediente',
                isDense: true,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Criar ingrediente novo'),
            subtitle: Text('«${widget.descricaoFatura}»'),
            onTap: () => Navigator.pop(context, const _EscolhaNovo()),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: itens.length,
              itemBuilder: (_, i) => ListTile(
                title: Text(itens[i].nome),
                subtitle: Text(
                  [
                    if (itens[i].marca.isNotEmpty) itens[i].marca,
                    if (itens[i].gramasEmbalagem > 0)
                      gramasParaTexto(itens[i].gramasEmbalagem),
                  ].join(' · '),
                ),
                onTap: () =>
                    Navigator.pop(context, _EscolhaExistente(itens[i])),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
