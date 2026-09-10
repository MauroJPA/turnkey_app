import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/formatting/money_provider.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/help_actions.dart';
import '../../import_csv/application/ingredient_import_service.dart';
import '../../import_csv/domain/import_result.dart';
import '../../recipes/application/recipes_providers.dart';
import '../../recipes/presentation/nutricao_receita_sheet.dart';
import '../application/ingredients_providers.dart';
import '../domain/ingredient.dart';
import 'ingredient_form_sheet.dart';
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

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _podeEditar => ref.read(currentPapelProvider).canEditBusiness;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final input = await showIngredientFormSheet(context);
    if (input == null) return;
    await _run(() => ref.read(ingredientActionsProvider).create(input));
  }

  Future<void> _edit(Ingrediente i) async {
    final input = await showIngredientFormSheet(context, existente: i);
    if (input == null) return;
    await _run(() => ref.read(ingredientActionsProvider).update(i.id, input));
  }

  Future<void> _nutricao(Ingrediente i) async {
    // Produto Gookie: a nutrição vem da receita — abre a folha da receita
    // (que lista os ingredientes/subprodutos a preencher, em cascata).
    if (i.eProdutoGookie) {
      final recs = ref.read(recipesListProvider(false)).valueOrNull;
      final rec =
          recs?.where((r) => r.id == i.receitaEspelhoId).firstOrNull;
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
      mensagem: 'Procura na Tabela da Composição de Alimentos (INSA) um '
          'alimento parecido com cada ingrediente SEM nutrição e preenche '
          'os valores + alergénios quando há uma correspondência clara. '
          'Os que ficarem em dúvida são marcados "por rever" para tu '
          'escolheres. Podes sempre editar depois.',
      confirmar: 'Preencher',
    );
    if (!ok) return;
    await _run(() async {
      final r =
          await ref.read(ingredientActionsProvider).autoPreencherInsa();
      if (!mounted) return;
      final rever = r.porRever + r.semCorrespondencia;
      setState(() => _soRevisao = rever > 0);
      unawaited(showDialog<void>(
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
      ));
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
      final q = _query.toLowerCase();
      final matchQ = q.isEmpty ||
          i.nome.toLowerCase().contains(q) ||
          i.marca.toLowerCase().contains(q) ||
          i.caracteristica.toLowerCase().contains(q);
      final matchF = _fornecedor == 'Todos' || i.fornecedor == _fornecedor;
      final matchR = !_soRevisao || i.precisaRevisaoInsa;
      return matchQ && matchF && matchR;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(ingredientsListProvider(_trash));
    // mantém as receitas carregadas para o redireccionamento dos produtos
    // Gookie (_nutricao).
    ref.watch(recipesListProvider(false));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
        title: Text(_trash ? 'Ingredientes · Lixeira' : 'Ingredientes'),
        actions: [
          const HelpActions(topic: HelpTopic.ingredientes),
          if (_podeEditar && !_trash)
            IconButton(
              tooltip: 'Preencher nutrição pela tabela INSA',
              icon: const Icon(Icons.auto_awesome_outlined),
              onPressed: _busy ? null : _autoInsa,
            ),
          if (_podeEditar && !_trash)
            IconButton(
              tooltip: 'Importar CSV',
              icon: const Icon(Icons.upload_file),
              onPressed: _busy ? null : _import,
            ),
          IconButton(
            tooltip: _trash ? 'Ver ativos' : 'Lixeira',
            icon: Icon(_trash ? Icons.inventory_2_outlined : Icons.delete_outline),
            onPressed: () => setState(() => _trash = !_trash),
          ),
          if (_podeEditar && !_trash)
            IconButton(
              tooltip: 'Novo ingrediente',
              icon: const Icon(Icons.add),
              onPressed: _busy ? null : _add,
            ),
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
              onRetry: () =>
                  ref.invalidate(ingredientsListProvider(_trash)),
              data: (all) {
                final fornecedores = <String>{
                  'Todos',
                  for (final i in all)
                    if (i.fornecedor.isNotEmpty) i.fornecedor,
                };
                final nRever =
                    all.where((i) => i.precisaRevisaoInsa).length;
                if (_soRevisao && nRever == 0) _soRevisao = false;
                final items = _filter(all);
                return Column(
                  children: [
                    if (nRever > 0)
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(12, 4, 12, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FilterChip(
                            avatar: const Icon(Icons.rule, size: 18),
                            label: Text('Por rever da INSA ($nRever)'),
                            selected: _soRevisao,
                            onSelected: (v) =>
                                setState(() => _soRevisao = v),
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
                          ],
                        ),
                      ),
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
      if (i.marca.isNotEmpty) i.marca,
      if (i.fornecedor.isNotEmpty) i.fornecedor,
      if (!i.disponivel) 'indisponível',
      if (i.alergenios.isNotEmpty) 'contém: ${i.alergenios.join(', ')}',
    ].join(' · ');

    final trailing = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          fmt(i.preco),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        if (i.gramasEmbalagem > 0)
          Text(
            '${fmt(i.custoPorGrama * 1000)}/kg',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );

    if (_trash) {
      return ListTile(
        title: Text(i.nome),
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
                        () => ref
                            .read(ingredientActionsProvider)
                            .restore(i.id),
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
      title: Text(i.nome),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          trailing,
          if (_podeEditar)
            IconButton(
              tooltip: i.precisaRevisaoInsa
                  ? 'Escolher o alimento certo da tabela INSA (por rever)'
                  : 'Nutrição e alergénios',
              icon: Icon(
                i.precisaRevisaoInsa
                    ? Icons.rule
                    : i.temNutri
                        ? Icons.local_dining
                        : Icons.local_dining_outlined,
                size: 20,
                color: i.precisaRevisaoInsa
                    ? Theme.of(context).colorScheme.tertiary
                    : i.temNutri
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).disabledColor,
              ),
              onPressed: () => _nutricao(i),
            ),
        ],
      ),
      onTap: _podeEditar ? () => _edit(i) : null,
      onLongPress: _podeEditar
          ? () => _run(
                () => ref.read(ingredientActionsProvider).duplicate(i),
              )
          : null,
    );

    if (!_podeEditar) return tile;

    return Dismissible(
      key: ValueKey(i.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline),
      ),
      confirmDismiss: (_) => confirmDialog(
        context,
        titulo: 'Mover para a lixeira',
        mensagem: 'Mover "${i.nome}" para a lixeira?',
        confirmar: 'Mover',
      ),
      onDismissed: (_) =>
          _run(() => ref.read(ingredientActionsProvider).moveToTrash(i.id)),
      child: tile,
    );
  }
}
