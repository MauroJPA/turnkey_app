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
import '../../consumables/application/consumivel_providers.dart';
import '../../consumables/domain/consumivel.dart';
import '../../consumables/presentation/consumiveis_screen.dart'
    show apresentaEstadoFds;
import '../../consumables/presentation/consumivel_sheet.dart';
import '../../ingredients/application/ingredients_providers.dart';
import '../../ingredients/data/ingredient_product_repository.dart';
import '../../ingredients/data/ingredient_repository.dart';
import '../../ingredients/domain/ingredient.dart';
import '../../ingredients/domain/produto_ingrediente.dart';
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
            data: (ings) => ref
                .watch(produtosIngredienteProvider)
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _Revisao(
                    fatura: fatura,
                    ingredientes: ings,
                    produtos: const [],
                    consumiveis: const [],
                  ),
                  data: (prods) => ref
                      .watch(consumiveisListProvider)
                      .when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => _Revisao(
                          fatura: fatura,
                          ingredientes: ings,
                          produtos: prods,
                          consumiveis: const [],
                        ),
                        data: (cons) => _Revisao(
                          fatura: fatura,
                          ingredientes: ings,
                          produtos: prods,
                          consumiveis: cons,
                        ),
                      ),
                ),
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

/// 250 -> "250"; 2,5 -> "2.5" (sem zeros a mais).
String _fmtNum(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}

/// Converte entre g e ml (com a densidade em g/ml). `null` = sem conversão
/// conhecida (por exemplo, unidades para gramas).
double? _converter(double v, String de, String para, {double densidade = 1}) {
  if (de == para) return v;
  final d = densidade > 0 ? densidade : 1;
  if (de == 'g' && para == 'ml') return v / d;
  if (de == 'ml' && para == 'g') return v * d;
  return null;
}

String _normNome(String s) =>
    s.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

class _LinhaState {
  _LinhaState(this.ia, MatchLinha? match, bool isLista, {Consumivel? consMatch})
    : consumivel = ia.consumivel,
      cons = consMatch,
      categoria = CategoriaConsumivel.values.firstWhere(
        (c) => c.api == ia.categoriaConsumivel,
        orElse: () => CategoriaConsumivel.limpeza,
      ),
      ingrediente = match?.ingrediente,
      produto = match?.produto,
      marca = TextEditingController(
        text: ia.marca.isNotEmpty ? ia.marca : (match?.produto?.marca ?? ''),
      ),
      // "2 un" de 15 g: mostra 2 unidades (=30 g); "200 g": mostra 200 g; "1 L": 1000 ml
      unidadeQtd = ia.contaEmbalagens ? 'un' : (ia.unidadeEVolume ? 'ml' : 'g'),
      qtd = TextEditingController(
        text: ia.contaEmbalagens
            ? ((ia.quantidade ?? 0) > 0 ? _fmtNum(ia.quantidade!) : '')
            : (ia.quantidadeG > 0 ? ia.quantidadeG.toStringAsFixed(0) : ''),
      ),
      // a embalagem lida vem na unidade da IA; a do ingrediente/produto ligado, na dele
      unidadeEmb = (ia.embalagemG ?? 0) > 0
          ? ia.embalagemUnidade
          : (match?.ingrediente.un ?? 'g'),
      unidadeIng = (ia.embalagemG ?? 0) > 0
          ? ia.embalagemUnidade
          : (ia.contaEmbalagens ? 'g' : (ia.unidadeEVolume ? 'ml' : 'g')),
      caracteristica = TextEditingController(text: ia.caracteristica),
      preco = TextEditingController(
        text: (ia.precoUnitario ?? 0) > 0
            ? ia.precoUnitario!.toStringAsFixed(2)
            : '',
      ),
      emb = TextEditingController(
        text: (ia.embalagemG ?? 0) > 0
            ? ia.embalagemG!.toStringAsFixed(0)
            : (match?.produto != null && match!.produto!.embalagemG > 0
                  ? match.produto!.embalagemG.toStringAsFixed(0)
                  : (match != null && match.ingrediente.gramasEmbalagem > 0
                        ? match.ingrediente.gramasEmbalagem.toStringAsFixed(0)
                        : '')),
      ),
      nome = TextEditingController(text: ia.descricao),
      acao = match == null && consMatch == null
          ? AcaoFatura.ignorar
          : (isLista ? AcaoFatura.preco : AcaoFatura.ambos);

  final FaturaLinhaIa ia;

  /// A linha é limpeza/insumo (em vez de ingrediente).
  bool consumivel;

  /// Produto de limpeza/insumo ligado (null se vai criar um novo).
  Consumivel? cons;

  /// Categoria do consumível a criar.
  CategoriaConsumivel categoria;

  /// Ingrediente genérico ligado a esta linha (null se vai criar um novo).
  Ingrediente? ingrediente;

  /// Produto de compra já conhecido (null = vai criar um produto novo com esta marca).
  ProdutoIngrediente? produto;

  /// Marca do produto (lida pela IA; editável).
  final TextEditingController marca;

  /// Criar um ingrediente novo (com o nome do campo [nome]).
  bool criarNovo = false;

  /// Renomear o [ingrediente] ligado para [nome] — propaga a todas as receitas
  /// e fichas (que referenciam o ingrediente por id).
  bool renomear = false;

  /// Unidade da quantidade comprada: `g`, `ml` ou `un` (embalagens, cada uma
  /// com o tamanho do campo [emb]).
  String unidadeQtd;

  /// Unidade em que está escrito o campo [emb] (`g`, `ml` ou `un`).
  String unidadeEmb;

  /// Unidade do ingrediente NOVO a criar (`g`, `ml` ou `un`).
  String unidadeIng;

  /// Característica do ingrediente novo (T55, T65, integral…).
  final TextEditingController caracteristica;

  final TextEditingController qtd;
  final TextEditingController preco;
  final TextEditingController emb;

  /// Nome para o ingrediente novo / para o renomear.
  final TextEditingController nome;

  AcaoFatura acao;

  double _n(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.').trim()) ?? 0;

  /// Unidade do ingrediente desta linha: a do ingrediente ligado, ou a escolhida
  /// para o novo; sem ingrediente, a da embalagem.
  String get ingUn => criarNovo
      ? unidadeIng
      : (ingrediente?.un ?? (unidadeEmb == 'un' ? 'un' : unidadeEmb));

  double get _densidade => ingrediente?.nutriDensidade ?? 1;

  /// Embalagem convertida para a unidade do ingrediente (`null` se não dá).
  double? get embNaUnidade =>
      embV > 0 ? _converter(embV, unidadeEmb, ingUn, densidade: _densidade) : 0;

  /// Quantidade realmente comprada, na unidade do ingrediente (o que dá entrada
  /// no stock): unidades = nº de embalagens x tamanho da embalagem.
  double get gramasComprados {
    if (unidadeQtd == 'un') {
      final e = embNaUnidade;
      return (e == null || e <= 0) ? 0 : _n(qtd) * e;
    }
    return _converter(_n(qtd), unidadeQtd, ingUn, densidade: _densidade) ?? 0;
  }

  /// Aviso se as unidades não se entendem (ex.: embalagem em un, ingrediente em g).
  String? get problemaUnidade {
    if (embV > 0 && embNaUnidade == null) {
      return 'A embalagem está em $unidadeEmb e o ingrediente em $ingUn: '
          'não dá para converter. Muda uma das unidades.';
    }
    if (unidadeQtd != 'un' &&
        _n(qtd) > 0 &&
        _converter(_n(qtd), unidadeQtd, ingUn, densidade: _densidade) == null) {
      return 'O comprado está em $unidadeQtd e o ingrediente em $ingUn.';
    }
    return null;
  }

  double get precoV => _n(preco);
  double get embV => _n(emb);

  /// A descrição da fatura difere do nome do ingrediente ligado?
  bool get nomeDiferente =>
      ingrediente != null &&
      _normNome(ingrediente!.nome) != _normNome(ia.descricao);

  bool get temAlvo =>
      criarNovo || (consumivel ? cons != null : ingrediente != null);

  LinhaAAplicar toAplicar(String? ingredienteId, {String? consumivelId}) => (
    ingredienteId: ingredienteId,
    consumivelId: consumivelId,
    descricaoFatura: ia.descricao,
    quantidadeG: gramasComprados,
    precoUnitario: _n(preco),
    totalLinha: ia.total ?? 0,
    embalagemG: embNaUnidade ?? 0,
    acao: acao,
    produtoId: produto?.id,
    marca: marca.text.trim(),
    produtoNome: ia.descricao,
  );
}

class _Revisao extends ConsumerStatefulWidget {
  const _Revisao({
    required this.fatura,
    required this.ingredientes,
    required this.produtos,
    required this.consumiveis,
  });
  final Fatura fatura;
  final List<Ingrediente> ingredientes;
  final List<ProdutoIngrediente> produtos;
  final List<Consumivel> consumiveis;

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
          ia.consumivel ? null : _matchIngrediente(ia),
          _isLista,
          consMatch: ia.consumivel ? _matchConsumivel(ia) : null,
        ),
    ];
  }

  MatchLinha? _matchIngrediente(FaturaLinhaIa ia) => emparelharLinha(
    descricao: ia.descricao,
    nomeGenerico: ia.nomeGenerico,
    marca: ia.marca,
    caracteristica: ia.caracteristica,
    embalagemG: ia.embalagemG ?? 0,
    ingredientes: widget.ingredientes,
    produtos: widget.produtos,
  );

  Consumivel? _matchConsumivel(FaturaLinhaIa ia) => emparelharConsumivel(
    descricao: ia.descricao,
    nomeGenerico: ia.nomeGenerico,
    marca: ia.marca,
    consumiveis: widget.consumiveis,
  );

  /// Muda a linha entre "ingrediente" e "limpeza/insumo" e volta a procurar
  /// a correspondência do novo tipo.
  void _mudarTipo(_LinhaState l, bool consumivel) {
    if (l.consumivel == consumivel) return;
    setState(() {
      l.consumivel = consumivel;
      l.criarNovo = false;
      l.renomear = false;
      l.ingrediente = null;
      l.produto = null;
      l.cons = null;
      if (consumivel) {
        l.cons = _matchConsumivel(l.ia);
      } else {
        final m = _matchIngrediente(l.ia);
        l.ingrediente = m?.ingrediente;
        l.produto = m?.produto;
      }
      if (l.temAlvo && l.acao == AcaoFatura.ignorar) {
        l.acao = _isLista || consumivel ? AcaoFatura.preco : AcaoFatura.ambos;
      }
      if (consumivel &&
          (l.acao == AcaoFatura.stock || l.acao == AcaoFatura.ambos)) {
        l.acao = AcaoFatura.preco;
      }
    });
  }

  Future<void> _escolherConsumivel(_LinhaState l) async {
    final r = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ConsumivelPicker(
        consumiveis: widget.consumiveis,
        sugestaoNome: l.ia.nomeGenerico.isNotEmpty
            ? l.ia.nomeGenerico
            : l.ia.descricao,
      ),
    );
    if (r == null) return;
    setState(() {
      if (l.acao == AcaoFatura.ignorar) l.acao = AcaoFatura.preco;
      if (r is Consumivel) {
        l.cons = r;
        l.criarNovo = false;
      } else {
        l.cons = null;
        l.criarNovo = true;
        l.nome.text = l.ia.nomeGenerico.isNotEmpty
            ? l.ia.nomeGenerico
            : l.ia.descricao;
      }
    });
  }

  Future<void> _escolherIngrediente(_LinhaState l) async {
    final r = await showModalBottomSheet<_EscolhaIngrediente>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _IngredientePicker(
        ingredientes: widget.ingredientes,
        descricaoFatura: l.ia.descricao,
        sugestaoNome: l.ia.nomeGenerico.isNotEmpty
            ? l.ia.nomeGenerico
            : l.ia.descricao,
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
          l.produto = produtoDaMarca(
            ing,
            widget.produtos,
            marca: l.marca.text,
            embalagemG: l.embV,
          );
          if (l.emb.text.trim().isEmpty && ing.gramasEmbalagem > 0) {
            l.emb.text = ing.gramasEmbalagem.toStringAsFixed(0);
          }
        case _EscolhaNovo():
          l.ingrediente = null;
          l.produto = null;
          l.criarNovo = true;
          l.renomear = false;
          l.nome.text = l.ia.nomeGenerico.isNotEmpty
              ? l.ia.nomeGenerico
              : l.ia.descricao;
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
            'Há linhas sem ingrediente ou produto. Liga, cria um novo, ou '
            'põe em Ignorar.',
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
    final semUnidade = aAplicar.where(
      (l) => !l.consumivel && l.problemaUnidade != null,
    );
    if (semUnidade.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(semUnidade.first.problemaUnidade!)),
      );
      return;
    }
    final novos = aAplicar.where((l) => l.criarNovo && !l.consumivel).length;
    final novosCons = aAplicar.where((l) => l.criarNovo && l.consumivel).length;
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
        final at = l.produto?.precoAtualizadoEm;
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
        if (novosCons > 0)
          'Cria $novosCons produto(s) de limpeza/insumos novo(s).',
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
      final consIds = <_LinhaState, String?>{};
      for (final l in _linhas) {
        if (l.acao == AcaoFatura.ignorar) {
          ids[l] = null;
          continue;
        }
        if (l.consumivel) {
          if (l.criarNovo) {
            // o preço e o nome da fatura ficam ao aplicar (no servidor)
            final novo = await ref
                .read(consumivelActionsProvider)
                .criar(
                  ConsumivelInput(
                    nome: l.nome.text.trim(),
                    categoria: l.categoria,
                    marca: l.marca.text.trim(),
                    fornecedor: forn,
                    exigeFds: l.categoria.exigeFdsPorOmissao,
                  ),
                );
            consIds[l] = novo.id;
          } else {
            consIds[l] = l.cons?.id;
          }
          continue;
        }
        if (l.criarNovo) {
          final novo = await repo.create(
            IngredienteInput(
              nome: l.nome.text.trim(),
              caracteristica: l.caracteristica.text.trim(),
              unidade: l.unidadeIng,
              // o preço e a marca ficam no produto de compra, criado ao aplicar
              // (só numa linha "só stock" é que o preço vai já no ingrediente)
              preco: l.acao == AcaoFatura.stock ? l.precoV : 0,
              gramasEmbalagem: l.acao == AcaoFatura.stock
                  ? (l.embNaUnidade ?? 0)
                  : 0,
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
              unidade: ing.un,
              gramasUnidade: ing.gramasUnidade,
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
            _linhas
                .map((l) => l.toAplicar(ids[l], consumivelId: consIds[l]))
                .toList(),
          );
      ref.invalidate(ingredientsListProvider);
      ref.invalidate(produtosIngredienteProvider);
      ref.invalidate(consumiveisListProvider);
      ref.invalidate(consumivelDocumentosProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            [
              '${res.precos} preço(s), ${res.movimentos} entrada(s) de stock',
              if (res.precosIgnorados > 0)
                '${res.precosIgnorados} preço(s) mantidos (fatura mais antiga)',
              if (novos > 0) '$novos novo(s)',
              if (novosCons > 0) '$novosCons produto(s) de limpeza/insumos',
              if (renomes > 0) '$renomes renomeado(s)',
            ].join(' · '),
          ),
        ),
      );
      final usados = {
        for (final id in consIds.values)
          if (id != null) id,
      };
      if (usados.isNotEmpty) await _avisarFdsEmFalta(usados);
      if (mounted && context.canPop()) context.pop();
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

  /// Depois de aplicar: lista os produtos desta fatura a que falta a ficha de
  /// dados de segurança (ou que a têm desatualizada), com atalho para anexar.
  Future<void> _avisarFdsEmFalta(Set<String> ids) async {
    try {
      final lista = await ref.read(consumiveisListProvider.future);
      final docs = await ref.read(consumivelDocumentosProvider.future);
      final pendentes = [
        for (final c in lista)
          if (ids.contains(c.id) &&
              const {EstadoFds.falta, EstadoFds.antiga}.contains(
                estadoFds(c, docs.where((d) => d.consumivelId == c.id)),
              ))
            c,
      ];
      if (pendentes.isEmpty || !mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Falta a ficha de segurança'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Estes produtos não têm a ficha de dados de segurança '
                  '(ou é antiga). Pede-a ao fornecedor e anexa-a:',
                ),
                for (final c in pendentes)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(c.nome),
                    trailing: TextButton(
                      onPressed: () => abrirConsumivelSheet(ctx, existente: c),
                      child: const Text('Anexar'),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Depois'),
            ),
          ],
        ),
      );
    } on Object {
      // o aviso é só um extra: nunca impede de concluir a fatura
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

  Widget _dropUnidade(String valor, void Function(String) onChanged) =>
      DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: valor,
          isDense: true,
          items: const [
            DropdownMenuItem(value: 'g', child: Text('g')),
            DropdownMenuItem(value: 'ml', child: Text('ml')),
            DropdownMenuItem(value: 'un', child: Text('un')),
          ],
          onChanged: (u) {
            if (u != null) onChanged(u);
          },
        ),
      );

  /// "Comprado": em g, ml ou un (nº de embalagens). Mudar a unidade converte o
  /// número já escrito, se a embalagem se conhece.
  Widget _campoComprado(_LinhaState l) => TextField(
    controller: l.qtd,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    onChanged: (_) => setState(() {}),
    decoration: InputDecoration(
      labelText: 'Comprado',
      isDense: true,
      helperText: l.unidadeQtd == 'un'
          ? (l.gramasComprados > 0
                ? '= ${_fmtNum(l.gramasComprados)} ${l.ingUn}'
                : 'Indica a embalagem')
          : null,
      suffix: _dropUnidade(l.unidadeQtd, (u) {
        setState(() {
          if (u == l.unidadeQtd) return;
          final atual = l.gramasComprados; // na unidade do ingrediente
          if (atual > 0) {
            if (u == 'un') {
              final e = l.embNaUnidade;
              if (e != null && e > 0) l.qtd.text = _fmtNum(atual / e);
            } else {
              final v = _converter(
                atual,
                l.ingUn,
                u,
                densidade: l.ingrediente?.nutriDensidade ?? 1,
              );
              if (v != null) l.qtd.text = _fmtNum(v);
            }
          }
          l.unidadeQtd = u;
        });
      }),
    ),
  );

  /// "Embalagem": tamanho de cada embalagem, em g, ml ou un.
  Widget _campoEmbalagem(_LinhaState l) => TextField(
    controller: l.emb,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    onChanged: (_) => setState(() {}),
    decoration: InputDecoration(
      labelText: 'Embalagem (tamanho)',
      isDense: true,
      helperText:
          l.embV > 0 && l.embNaUnidade != null && l.unidadeEmb != l.ingUn
          ? '= ${_fmtNum(l.embNaUnidade!)} ${l.ingUn} (o ingrediente está em ${l.ingUn})'
          : null,
      suffix: _dropUnidade(
        l.unidadeEmb,
        (u) => setState(() => l.unidadeEmb = u),
      ),
    ),
  );

  /// Campos de uma linha que é limpeza/insumo: produto, marca e documentos.
  List<Widget> _blocoConsumivel(_LinhaState l) {
    final docs =
        ref.watch(consumivelDocumentosProvider).valueOrNull ?? const [];
    final cs = Theme.of(context).colorScheme;
    final meus = l.cons == null
        ? const <DocumentoConsumivel>[]
        : docs.where((d) => d.consumivelId == l.cons!.id).toList();
    final estado = l.cons == null ? null : estadoFds(l.cons!, meus);
    final ap = estado == null ? null : apresentaEstadoFds(estado, cs);
    return [
      InkWell(
        onTap: () => _escolherConsumivel(l),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Produto de limpeza / insumo',
            isDense: true,
            suffixIcon: const Icon(Icons.arrow_drop_down),
            helperText: l.criarNovo ? 'Vai criar um produto novo' : null,
          ),
          child: Text(
            l.criarNovo
                ? 'Novo produto'
                : (l.cons?.nome ?? 'Escolher produto…'),
            style: TextStyle(color: !l.temAlvo ? cs.error : null),
          ),
        ),
      ),
      if (l.criarNovo) ...[
        const SizedBox(height: 8),
        TextField(
          controller: l.nome,
          decoration: const InputDecoration(
            labelText: 'Nome do produto novo',
            isDense: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<CategoriaConsumivel>(
          key: ValueKey('${identityHashCode(l)}_${l.categoria.name}'),
          initialValue: l.categoria,
          decoration: const InputDecoration(
            labelText: 'Categoria',
            isDense: true,
          ),
          items: [
            for (final c in CategoriaConsumivel.values)
              DropdownMenuItem(value: c, child: Text(c.label)),
          ],
          onChanged: (c) => setState(() => l.categoria = c ?? l.categoria),
        ),
        const SizedBox(height: 4),
        Text(
          l.categoria.exigeFdsPorOmissao
              ? 'Vai ficar a pedir a ficha de dados de segurança.'
              : 'Não pede ficha de dados de segurança (podes mudar depois).',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
      if (l.cons != null && ap != null) ...[
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(ap.icone, size: 18, color: ap.cor),
            Text(
              meus.isEmpty
                  ? ap.texto
                  : '${ap.texto} · ${meus.length} documento(s) já anexado(s)',
              style: TextStyle(color: ap.cor),
            ),
            TextButton(
              onPressed: () => abrirConsumivelSheet(context, existente: l.cons),
              child: const Text('Documentos'),
            ),
          ],
        ),
      ],
      const SizedBox(height: 8),
      TextField(
        controller: l.marca,
        decoration: const InputDecoration(labelText: 'Marca', isDense: true),
      ),
    ];
  }

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
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                    segments: const [
                      ButtonSegment(value: false, label: Text('Ingrediente')),
                      ButtonSegment(
                        value: true,
                        label: Text('Limpeza / insumo'),
                      ),
                    ],
                    selected: {l.consumivel},
                    onSelectionChanged: (v) => _mudarTipo(l, v.first),
                  ),
                  const SizedBox(height: 6),
                  if (l.consumivel)
                    ..._blocoConsumivel(l)
                  else
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
                              : (l.ingrediente?.nomeComCaracteristica ??
                                    'Escolher ingrediente…'),
                          style: TextStyle(
                            color: !l.temAlvo
                                ? Theme.of(context).colorScheme.error
                                : null,
                          ),
                        ),
                      ),
                    ),
                  if (!l.consumivel &&
                      (l.ingrediente != null || l.criarNovo)) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: l.marca,
                      decoration: InputDecoration(
                        labelText: 'Marca',
                        isDense: true,
                        helperText: l.produto != null
                            ? 'Produto já conhecido: ${l.produto!.resumo}'
                            : 'Vai criar um produto novo (marca e embalagem) '
                                  'neste ingrediente',
                        helperMaxLines: 2,
                      ),
                      onChanged: (v) => setState(() {
                        if (l.ingrediente != null) {
                          l.produto = produtoDaMarca(
                            l.ingrediente!,
                            widget.produtos,
                            marca: v,
                            embalagemG: l.embV,
                          );
                        }
                      }),
                    ),
                  ],
                  if (!l.consumivel && (l.criarNovo || l.renomear)) ...[
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
                    if (l.criarNovo) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: l.caracteristica,
                        decoration: const InputDecoration(
                          labelText: 'Característica (opcional)',
                          hintText: 'T55, T65, integral, 70% cacau…',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Unidade do ingrediente',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      SegmentedButton<String>(
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                        ),
                        segments: const [
                          ButtonSegment(value: 'g', label: Text('g')),
                          ButtonSegment(value: 'ml', label: Text('ml')),
                          ButtonSegment(value: 'un', label: Text('un')),
                        ],
                        selected: {l.unidadeIng},
                        onSelectionChanged: (v) =>
                            setState(() => l.unidadeIng = v.first),
                      ),
                    ],
                  ],
                  if (!l.consumivel && l.ingrediente != null && l.nomeDiferente)
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
                      if (!_isLista && !l.consumivel) ...[
                        Expanded(child: _campoComprado(l)),
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
                    ],
                  ),
                  if (!l.consumivel) ...[
                    const SizedBox(height: 8),
                    _campoEmbalagem(l),
                    if (l.problemaUnidade != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          l.problemaUnidade!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
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
                        if ((!_isLista && !l.consumivel) ||
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
          label: const Text('Aplicar'),
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
    required this.sugestaoNome,
  });
  final List<Ingrediente> ingredientes;
  final String descricaoFatura;
  final String sugestaoNome;

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
            title: const Text('Criar ingrediente novo (genérico)'),
            subtitle: Text('«${widget.sugestaoNome}»'),
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

class _ConsumivelPicker extends StatefulWidget {
  const _ConsumivelPicker({
    required this.consumiveis,
    required this.sugestaoNome,
  });
  final List<Consumivel> consumiveis;
  final String sugestaoNome;

  @override
  State<_ConsumivelPicker> createState() => _ConsumivelPickerState();
}

class _ConsumivelPickerState extends State<_ConsumivelPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final itens = widget.consumiveis
        .where(
          (c) =>
              _q.isEmpty ||
              '${c.nome} ${c.marca}'.toLowerCase().contains(_q.toLowerCase()),
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
                hintText: 'Procurar produto',
                isDense: true,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Criar produto novo'),
            subtitle: Text('«${widget.sugestaoNome}»'),
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
                    itens[i].categoria.label,
                    if (itens[i].marca.isNotEmpty) itens[i].marca,
                  ].join(' · '),
                ),
                onTap: () => Navigator.pop(context, itens[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
