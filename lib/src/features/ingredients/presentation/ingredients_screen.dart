import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketbase/pocketbase.dart' show ClientException;

import '../../../app/router.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/data/marcas_fornecedores_providers.dart';
import '../../../core/errors/mensagem_amigavel.dart';
import '../../../core/formatting/money_provider.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/help_actions.dart';
import '../../../core/widgets/sort_menu_button.dart';
import '../../../core/widgets/swipe_to_delete.dart';
import '../../import_csv/application/ingredient_import_service.dart';
import '../../import_csv/domain/import_result.dart';
import '../../recipes/application/recipes_providers.dart';
import '../../recipes/presentation/nutricao_receita_sheet.dart';
import '../application/ingredients_providers.dart';
import '../data/ingredient_repository.dart';
import '../domain/ingredient.dart';
import 'ingredient_form_sheet.dart';
import 'juntar_ingrediente_sheet.dart';
import 'juntar_marcas_fornecedores_sheet.dart';
import 'nutricao_sheet.dart';

class IngredientsScreen extends ConsumerStatefulWidget {
  const IngredientsScreen({super.key});

  @override
  ConsumerState<IngredientsScreen> createState() => _IngredientsScreenState();
}

class _IngredientsScreenState extends ConsumerState<IngredientsScreen> {
  final _search = TextEditingController();
  String _query = '';
  String _fornecedor = 'Todos';
  bool _trash = false;
  bool _busy = false;
  bool _soRevisao = false;
  bool _selecionandoJuntar = false;
  final Set<String> _selecionadosJuntar = {};

  static final List<SortOption<Ingrediente>> _sortOptions = [
    SortOption<Ingrediente>(
      'Nome',
      (a, b) => a.nomeComCaracteristica.toLowerCase().compareTo(
        b.nomeComCaracteristica.toLowerCase(),
      ),
    ),
    SortOption<Ingrediente>('Preço', (a, b) => a.preco.compareTo(b.preco)),
    SortOption<Ingrediente>(
      'Fornecedor',
      (a, b) =>
          a.fornecedor.toLowerCase().compareTo(b.fornecedor.toLowerCase()),
    ),
  ];
  int _sortIndex = 0;
  bool _sortAsc = true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _podeEditar => ref.read(currentPapelProvider).canEditBusiness;

  /// Junta [origem] com outro ingrediente (que fica): tudo passa para ele.
  Future<void> _juntar(Ingrediente origem) async {
    final todos = await ref.read(ingredientsListProvider(false).future);
    if (!mounted) return;
    final destino = await escolherDestinoJuntar(
      context,
      origem: origem,
      todos: todos,
    );
    if (destino == null || !mounted) return;
    final ok = await confirmDialog(
      context,
      titulo: 'Juntar ingredientes?',
      mensagem:
          '«${origem.nome}» passa a fazer parte de «${destino.nome}»: as '
          'receitas, fichas, stock, compras e produtos de compra passam '
          'para «${destino.nome}», e os alergénios juntam-se. «${origem.nome}» '
          'vai para a lixeira.',
      confirmar: 'Juntar',
    );
    if (!ok) return;
    final ResultadoJuntar r;
    setState(() => _busy = true);
    try {
      r = await ref
          .read(ingredientActionsProvider)
          .juntar(origem.id, destino.id);
      ref.invalidate(recipesListProvider);
    } on ClientException catch (e) {
      // só a mensagem do servidor (em português); nunca o erro de rede em bruto
      final msg = e.response['message'];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg is String && msg.isNotEmpty
                  ? msg
                  : 'Não foi possível juntar os ingredientes.',
            ),
          ),
        );
      }
      return;
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível juntar os ingredientes.'),
          ),
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    final extra = [
      if (r.alergeniosAdicionados.isNotEmpty)
        'Alergénios acrescentados: ${r.alergeniosAdicionados.join(', ')}.',
    ].join(' ');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '«${origem.nome}» juntou-se a «${destino.nome}». $extra'.trim(),
        ),
      ),
    );
  }

  void _iniciarSelecaoJuntar() => setState(() {
    _selecionandoJuntar = true;
    _selecionadosJuntar.clear();
  });

  void _sairSelecaoJuntar() => setState(() {
    _selecionandoJuntar = false;
    _selecionadosJuntar.clear();
  });

  void _alternarSelecaoJuntar(String id) => setState(() {
    if (_selecionadosJuntar.contains(id)) {
      _selecionadosJuntar.remove(id);
    } else {
      _selecionadosJuntar.add(id);
    }
  });

  Future<Ingrediente?> _escolherQualFica(List<Ingrediente> selecionados) {
    return showDialog<Ingrediente>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Qual ingrediente fica?'),
        children: [
          for (final i in selecionados)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, i),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(i.nome),
                subtitle: Text(
                  [
                    if (i.marca.isNotEmpty) i.marca,
                    if (i.fornecedor.isNotEmpty) i.fornecedor,
                  ].join(' · '),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Junta os ingredientes selecionados num só, escolhido de entre eles.
  Future<void> _juntarSelecionados(List<Ingrediente> todos) async {
    final selecionados = [
      for (final i in todos)
        if (_selecionadosJuntar.contains(i.id)) i,
    ];
    if (selecionados.length < 2) return;
    final destino = await _escolherQualFica(selecionados);
    if (destino == null || !mounted) return;
    final origens = [
      for (final i in selecionados)
        if (i.id != destino.id) i,
    ];
    final ok = await confirmDialog(
      context,
      titulo: 'Juntar ${selecionados.length} ingredientes?',
      mensagem:
          '«${origens.map((o) => o.nome).join('», «')}» passam a fazer '
          'parte de «${destino.nome}»: as receitas, fichas, stock, compras '
          'e produtos de compra passam para «${destino.nome}», e os '
          'alergénios juntam-se. Os outros vão para a lixeira.',
      confirmar: 'Juntar',
    );
    if (!ok) return;
    setState(() => _busy = true);
    var falhas = 0;
    final alergenios = <String>{};
    for (final o in origens) {
      try {
        final r = await ref
            .read(ingredientActionsProvider)
            .juntar(o.id, destino.id);
        alergenios.addAll(r.alergeniosAdicionados);
      } on Object {
        falhas++;
      }
    }
    ref.invalidate(recipesListProvider);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _selecionandoJuntar = false;
      _selecionadosJuntar.clear();
    });
    final extra = [
      if (falhas > 0) '$falhas não foi possível juntar.',
      if (alergenios.isNotEmpty)
        'Alergénios acrescentados: ${alergenios.join(', ')}.',
    ].join(' ');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${origens.length} ingrediente(s) juntaram-se a «${destino.nome}». '
                  '$extra'
              .trim(),
        ),
      ),
    );
  }

  Future<bool> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      return true;
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final res = await showIngredientFormSheet(context);
    if (res == null) return;
    Ingrediente? criado;
    await _run(() async {
      criado = await ref
          .read(ingredientActionsProvider)
          .create(res.input, nutri: res.nutri);
    });
    final novo = criado;
    if (res.abrirNutricao && novo != null && mounted) {
      await showNutricaoSheet(context, ingrediente: novo);
    }
  }

  Future<void> _edit(Ingrediente i) async {
    final res = await showIngredientFormSheet(context, existente: i);
    if (res == null) return;
    await _run(
      () => ref.read(ingredientActionsProvider).update(i.id, res.input),
    );
  }

  Future<void> _nutricao(Ingrediente i) async {
    // Produto de fabrico próprio: a nutrição vem da receita — abre a folha da receita
    // (que lista os ingredientes/subprodutos a preencher, em cascata).
    if (i.eProdutoProprio) {
      final recs = ref.read(recipesListProvider(false)).valueOrNull;
      final rec = recs?.where((r) => r.id == i.receitaEspelhoId).firstOrNull;
      if (rec != null) {
        await showNutricaoReceitaSheet(context, receita: rec);
        return;
      }
    }
    if (mounted) await showNutricaoSheet(context, ingrediente: i);
  }

  Future<void> _autoInsa() async {
    final ok = await confirmDialog(
      context,
      titulo: 'Preencher pela tabela INSA?',
      mensagem:
          'Procura na Tabela da Composição de Alimentos (INSA) um '
          'alimento parecido com cada ingrediente SEM nutrição e preenche '
          'os valores + alergénios quando há uma correspondência clara. '
          'Os que ficarem em dúvida são marcados "por rever" para tu '
          'escolheres. Podes sempre editar depois.',
      confirmar: 'Preencher',
    );
    if (!ok) return;
    await _run(() async {
      final r = await ref.read(ingredientActionsProvider).autoPreencherInsa();
      if (!mounted) return;
      final rever = r.porRever + r.semCorrespondencia;
      setState(() => _soRevisao = rever > 0);
      unawaited(
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Tabela INSA'),
            content: Text(
              r.total == 0
                  ? 'Todos os ingredientes já tinham nutrição.'
                  : 'Preenchidos automaticamente: ${r.aplicados}.\n'
                        'Por rever (escolher o alimento certo): ${r.porRever}.\n'
                        'Sem correspondência na INSA: ${r.semCorrespondencia}.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _import() async {
    await _run(() async {
      final ImportResult res;
      try {
        res = await ref.read(ingredientImportServiceProvider).pickAndImport();
      } on ImportCancelled {
        return;
      }
      if (!mounted) return;
      final msg = res.semErros
          ? 'Importação concluída: ${res.resumo}.'
          : 'Importado (${res.resumo}) com ${res.erros.length} erro(s).';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          action: res.semErros
              ? null
              : SnackBarAction(
                  label: 'Ver',
                  onPressed: () => _showErrors(res.erros),
                ),
        ),
      );
    });
  }

  void _showErrors(List<String> erros) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Erros na importação'),
        content: SizedBox(
          width: 400,
          child: ListView(
            shrinkWrap: true,
            children: [for (final e in erros) Text('• $e')],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  List<Ingrediente> _filter(List<Ingrediente> all) {
    return all.where((i) {
      final matchQ = i.correspondeABusca(_query);
      final matchF = _fornecedor == 'Todos' || i.fornecedor == _fornecedor;
      final matchR = !_soRevisao || i.precisaRevisaoInsa;
      return matchQ && matchF && matchR;
    }).toList();
  }

  /// Legenda dos ícones de nutrição (o ícone à direita de cada ingrediente).
  Widget _legendaNutri() {
    final cs = Theme.of(context).colorScheme;
    final itens = <(IconData, Color, String)>[
      (Icons.local_dining_outlined, Theme.of(context).disabledColor, 'sem'),
      (Icons.rule, cs.error, 'por rever'),
      (Icons.menu_book, cs.primary, 'INSA'),
      (Icons.edit_note, cs.secondary, 'à mão'),
      (Icons.photo_camera, cs.tertiary, 'à mão + foto'),
    ];
    return SizedBox(
      height: 30,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Text('Nutrição:  ', style: Theme.of(context).textTheme.bodySmall),
          for (final (ic, cor, txt) in itens)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(ic, size: 15, color: cor),
                  const SizedBox(width: 3),
                  Text(txt, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(ingredientsListProvider(_trash));
    // mantém as receitas carregadas para o redireccionamento dos produtos
    // de fabrico próprio (_nutricao).
    ref.watch(recipesListProvider(false));

    return Scaffold(
      appBar: _selecionandoJuntar
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cancelar seleção',
                onPressed: _sairSelecaoJuntar,
              ),
              title: Text('${_selecionadosJuntar.length} selecionado(s)'),
              actions: [
                TextButton(
                  onPressed: _selecionadosJuntar.length < 2
                      ? null
                      : () => _juntarSelecionados(
                          listAsync.valueOrNull ?? const <Ingrediente>[],
                        ),
                  child: const Text('Juntar'),
                ),
              ],
            )
          : AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go(Routes.home),
              ),
              title: Text(_trash ? 'Ingredientes · Lixeira' : 'Ingredientes'),
              actions: [
                if (!_trash)
                  SortMenuButton<Ingrediente>(
                    options: _sortOptions,
                    selectedIndex: _sortIndex,
                    ascending: _sortAsc,
                    onChanged: (i, asc) => setState(() {
                      _sortIndex = i;
                      _sortAsc = asc;
                    }),
                  ),
                if (_podeEditar && !_trash)
                  PopupMenuButton<String>(
                    tooltip: 'Mais ações',
                    icon: const Icon(Icons.more_vert),
                    onSelected: (v) {
                      if (v == 'juntar') {
                        mostrarJuntarMarcasFornecedores(context);
                      }
                      if (v == 'selecionar_juntar') _iniciarSelecaoJuntar();
                      if (v == 'insa') _autoInsa();
                      if (v == 'importar') _import();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'selecionar_juntar',
                        child: ListTile(
                          leading: Icon(Icons.checklist_outlined),
                          title: Text('Selecionar ingredientes para juntar'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      if (ref.read(currentPapelProvider).canEditConfig)
                        const PopupMenuItem(
                          value: 'juntar',
                          child: ListTile(
                            leading: Icon(Icons.join_full_outlined),
                            title: Text('Juntar marcas/fornecedores repetidos'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'insa',
                        child: ListTile(
                          leading: Icon(Icons.auto_awesome_outlined),
                          title: Text('Preencher nutrição pela tabela INSA'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'importar',
                        child: ListTile(
                          leading: Icon(Icons.upload_file),
                          title: Text('Importar CSV'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                IconButton(
                  tooltip: _trash ? 'Ver ativos' : 'Lixeira',
                  icon: Icon(
                    _trash ? Icons.inventory_2_outlined : Icons.delete_outline,
                  ),
                  onPressed: () => setState(() => _trash = !_trash),
                ),
                if (_podeEditar && !_trash)
                  IconButton(
                    tooltip: 'Novo ingrediente',
                    icon: const Icon(Icons.add),
                    onPressed: _busy ? null : _add,
                  ),
                const HelpActions(topic: HelpTopic.ingredientes),
              ],
            ),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Procurar por nome, marca ou tipo',
                isDense: true,
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: AsyncValueView<List<Ingrediente>>(
              value: listAsync,
              onRetry: () => ref.invalidate(ingredientsListProvider(_trash)),
              data: (all) {
                final fornecedores = <String>{
                  'Todos',
                  for (final i in all)
                    if (i.fornecedor.isNotEmpty) i.fornecedor,
                };
                final nRever = all.where((i) => i.precisaRevisaoInsa).length;
                if (_soRevisao && nRever == 0) _soRevisao = false;
                final items = ordenarPor(
                  _filter(all),
                  _sortOptions[_sortIndex],
                  _sortAsc,
                );
                return Column(
                  children: [
                    if (nRever > 0)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FilterChip(
                            avatar: const Icon(Icons.rule, size: 18),
                            label: Text('Por rever da INSA ($nRever)'),
                            selected: _soRevisao,
                            onSelected: (v) => setState(() => _soRevisao = v),
                          ),
                        ),
                      ),
                    if (fornecedores.length > 1)
                      SizedBox(
                        height: 44,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          children: [
                            for (final f in fornecedores)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(f),
                                  selected: _fornecedor == f,
                                  onSelected: (_) =>
                                      setState(() => _fornecedor = f),
                                ),
                              ),
                            if (fornecedores.length > 2 &&
                                ref.read(currentPapelProvider).canEditConfig)
                              ActionChip(
                                avatar: const Icon(
                                  Icons.join_full_outlined,
                                  size: 16,
                                ),
                                label: const Text('Juntar repetidos'),
                                onPressed: () =>
                                    mostrarJuntarMarcasFornecedores(
                                      context,
                                      tipoInicial: TipoCatalogo.fornecedor,
                                    ),
                              ),
                          ],
                        ),
                      ),
                    if (!_trash && _podeEditar) _legendaNutri(),
                    Expanded(
                      child: items.isEmpty
                          ? Center(
                              child: Text(
                                all.isEmpty
                                    ? (_trash
                                          ? 'Lixeira vazia'
                                          : 'Sem ingredientes. Usa + ou importa um CSV.')
                                    : 'Nada corresponde ao filtro.',
                              ),
                            )
                          : ListView.separated(
                              itemCount: items.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, idx) => _tile(
                                items[idx],
                                ref.watch(moneyFormatProvider),
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(Ingrediente i, MoneyFmt fmt) {
    final subtitle = [
      if (i.un != 'g') 'em ${i.un}',
      if (i.marca.isNotEmpty) i.marca,
      if (i.fornecedor.isNotEmpty) i.fornecedor,
      if (!i.disponivel) 'indisponível',
      if (i.alergenios.isNotEmpty) 'contém: ${i.alergenios.join(', ')}',
    ].join(' · ');

    if (_selecionandoJuntar) {
      final podeSelecionar = i.origem == OrigemIngrediente.comprado;
      return ListTile(
        leading: Checkbox(
          value: _selecionadosJuntar.contains(i.id),
          onChanged: podeSelecionar
              ? (_) => _alternarSelecaoJuntar(i.id)
              : null,
        ),
        title: Text(i.nomeComCaracteristica),
        subtitle: Text(
          podeSelecionar
              ? subtitle
              : 'Produto de fabrico próprio — não se pode juntar',
        ),
        enabled: podeSelecionar,
        onTap: podeSelecionar ? () => _alternarSelecaoJuntar(i.id) : null,
      );
    }

    final trailing = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(fmt(i.preco), style: const TextStyle(fontWeight: FontWeight.bold)),
        if (i.gramasEmbalagem > 0)
          Text(switch (i.un) {
            'ml' => '${fmt(i.custoPorGrama * 1000)}/L',
            'un' => '${fmt(i.custoPorGrama)}/un',
            _ => '${fmt(i.custoPorGrama * 1000)}/kg',
          }, style: Theme.of(context).textTheme.bodySmall),
      ],
    );

    if (_trash) {
      return ListTile(
        title: Text(i.nomeComCaracteristica),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Restaurar',
              icon: const Icon(Icons.restore),
              onPressed: _busy
                  ? null
                  : () => _run(
                      () => ref.read(ingredientActionsProvider).restore(i.id),
                    ),
            ),
            IconButton(
              tooltip: 'Apagar definitivamente',
              icon: const Icon(Icons.delete_forever),
              onPressed: _busy
                  ? null
                  : () async {
                      final ok = await confirmDialog(
                        context,
                        titulo: 'Apagar definitivamente',
                        mensagem: 'Isto não pode ser revertido.',
                        confirmar: 'Apagar',
                        destrutivo: true,
                      );
                      if (ok) {
                        await _run(
                          () => ref
                              .read(ingredientActionsProvider)
                              .deleteForever(i.id),
                        );
                      }
                    },
            ),
          ],
        ),
      );
    }

    final tile = ListTile(
      title: Text(i.nomeComCaracteristica),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          trailing,
          if (_podeEditar && i.origem == OrigemIngrediente.comprado)
            PopupMenuButton<String>(
              tooltip: 'Mais ações',
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (v) {
                if (v == 'juntar') _juntar(i);
                if (v == 'duplicar') {
                  _run(() => ref.read(ingredientActionsProvider).duplicate(i));
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'juntar',
                  child: Text('Juntar com outro ingrediente…'),
                ),
                PopupMenuItem(value: 'duplicar', child: Text('Duplicar')),
              ],
            ),
          if (_podeEditar)
            Builder(
              builder: (context) {
                final cs = Theme.of(context).colorScheme;
                final (IconData ic, Color cor) = switch (i.fonteNutri) {
                  FonteNutri.vazia => (
                    Icons.local_dining_outlined,
                    Theme.of(context).disabledColor,
                  ),
                  FonteNutri.porRever => (Icons.rule, cs.error),
                  FonteNutri.insa => (Icons.menu_book, cs.primary),
                  FonteNutri.manual => (Icons.edit_note, cs.secondary),
                  FonteNutri.comFoto => (Icons.photo_camera, cs.tertiary),
                  FonteNutri.irrelevante => (
                    Icons.block_outlined,
                    Theme.of(context).disabledColor,
                  ),
                };
                return IconButton(
                  tooltip: 'Nutrição: ${i.fonteNutri.label}',
                  icon: Icon(ic, size: 20, color: cor),
                  onPressed: () => _nutricao(i),
                );
              },
            ),
        ],
      ),
      onTap: _podeEditar ? () => _edit(i) : null,
      onLongPress: _podeEditar
          ? () => _run(() => ref.read(ingredientActionsProvider).duplicate(i))
          : null,
    );

    if (!_podeEditar) return tile;

    return SwipeToDelete(
      key: ValueKey(i.id),
      confirmar: () => confirmDialog(
        context,
        titulo: 'Mover para a lixeira',
        mensagem: 'Mover "${i.nome}" para a lixeira?',
        confirmar: 'Mover',
      ),
      apagar: () =>
          _run(() => ref.read(ingredientActionsProvider).moveToTrash(i.id)),
      child: tile,
    );
  }
}
