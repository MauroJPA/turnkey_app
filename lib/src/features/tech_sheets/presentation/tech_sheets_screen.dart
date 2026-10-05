import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/errors/mensagem_amigavel.dart';
import '../../../core/formatting/money_provider.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/help_actions.dart';
import '../../../core/widgets/pendencia_aviso.dart';
import '../../../core/widgets/sort_menu_button.dart';
import '../../../core/widgets/swipe_to_delete.dart';
import '../../cookie_formats/application/cookie_format_providers.dart';
import '../../pricing/data/cost_config_repository.dart';
import '../../pricing/domain/cost_config.dart';
import '../../products/domain/produto_rotulo.dart';
import '../application/tech_sheets_providers.dart';
import '../domain/tech_sheet.dart';
import 'ficha_form_sheet.dart';

class TechSheetsScreen extends ConsumerStatefulWidget {
  const TechSheetsScreen({super.key});

  @override
  ConsumerState<TechSheetsScreen> createState() => _TechSheetsScreenState();
}

class _TechSheetsScreenState extends ConsumerState<TechSheetsScreen> {
  String _q = '';
  String? _categoria;
  bool _soPorCompletar = false;
  bool _trash = false;
  bool _busy = false;

  static final List<SortOption<FichaTecnica>> _sortOptions = [
    SortOption<FichaTecnica>(
      'Nome',
      (a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()),
    ),
    SortOption<FichaTecnica>(
      'Custo',
      (a, b) => a.custoProduto.compareTo(b.custoProduto),
    ),
    SortOption<FichaTecnica>(
      'Preço de venda',
      (a, b) => a.precoVenda.compareTo(b.precoVenda),
    ),
  ];
  int _sortIndex = 0;
  bool _sortAsc = true;

  bool get _podeEditar => ref.read(currentPapelProvider).canEditBusiness;

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

  Future<void> _editarPrecoVenda(FichaTecnica f) async {
    final ctrl = TextEditingController(
      text: f.precoVenda > 0 ? f.precoVenda.toStringAsFixed(2) : '',
    );
    final novo = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Preço de venda — ${f.nome}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Preço',
            prefixText: '€ ',
          ),
          onSubmitted: (_) => Navigator.pop(
            ctx,
            double.tryParse(ctrl.text.replaceAll(',', '.')),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              double.tryParse(ctrl.text.replaceAll(',', '.')),
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (novo == null || novo == f.precoVenda) return;
    await _run(
      () => ref
          .read(fichaActionsProvider)
          .setPrecoVenda(f.id, novo < 0 ? 0 : novo),
    );
  }

  Future<void> _add() async {
    final input = await showFichaFormSheet(context);
    if (input == null) return;
    await _run(() async {
      final f = await ref.read(fichaActionsProvider).create(input);
      if (mounted) context.go('${Routes.techSheets}/${f.id}');
    });
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(fichasListProvider(_trash));
    final configAsync = ref.watch(costConfigProvider);
    final porCompletar = (listAsync.valueOrNull ?? const <FichaTecnica>[])
        .where((f) => pendenciasProduto(f).isNotEmpty)
        .length;
    final categoriasEmUso =
        (listAsync.valueOrNull ?? const <FichaTecnica>[])
            .map((f) => f.categoria)
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
        title: Text(_trash ? 'Fichas · Lixeira' : 'Fichas'),
        actions: [
          if (!_trash)
            SortMenuButton<FichaTecnica>(
              options: _sortOptions,
              selectedIndex: _sortIndex,
              ascending: _sortAsc,
              onChanged: (i, asc) => setState(() {
                _sortIndex = i;
                _sortAsc = asc;
              }),
            ),
          IconButton(
            tooltip: _trash ? 'Ver ativas' : 'Lixeira',
            icon: Icon(
              _trash ? Icons.receipt_long_outlined : Icons.delete_outline,
            ),
            onPressed: () => setState(() => _trash = !_trash),
          ),
          if (_podeEditar && !_trash)
            IconButton(
              tooltip: 'Nova ficha',
              icon: const Icon(Icons.add),
              onPressed: _busy ? null : _add,
            ),
          const HelpActions(topic: HelpTopic.fichas),
        ],
      ),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Procurar ficha',
                isDense: true,
              ),
            ),
          ),
          if (!_trash && (categoriasEmUso.length > 1 || porCompletar > 0))
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  if (porCompletar > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        avatar: const Icon(
                          Icons.local_dining_outlined,
                          size: 16,
                        ),
                        label: Text('Informação por completar ($porCompletar)'),
                        selected: _soPorCompletar,
                        onSelected: (v) => setState(() => _soPorCompletar = v),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('Todas'),
                      selected: _categoria == null,
                      onSelected: (_) => setState(() => _categoria = null),
                    ),
                  ),
                  for (final c in categoriasEmUso)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          '$c (${(listAsync.valueOrNull ?? const <FichaTecnica>[]).where((f) => f.categoria == c).length})',
                        ),
                        selected: _categoria == c,
                        onSelected: (_) => setState(() => _categoria = c),
                      ),
                    ),
                ],
              ),
            ),
          if (!_trash) _avisoPrecoEmFalta(listAsync.valueOrNull),
          Expanded(
            child: AsyncValueView<List<FichaTecnica>>(
              value: listAsync,
              onRetry: () => ref.invalidate(fichasListProvider(_trash)),
              data: (all) {
                final items = ordenarPor(
                  all
                      .where(
                        (f) =>
                            (_q.isEmpty ||
                                f.nome.toLowerCase().contains(
                                  _q.toLowerCase(),
                                )) &&
                            (_categoria == null || f.categoria == _categoria) &&
                            (!_soPorCompletar ||
                                pendenciasProduto(f).isNotEmpty),
                      )
                      .toList(),
                  _sortOptions[_sortIndex],
                  _sortAsc,
                );
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      all.isEmpty
                          ? (_trash
                                ? 'Lixeira vazia'
                                : 'Sem fichas. Usa + para criar.')
                          : 'Nada corresponde ao filtro.',
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _tile(
                    items[i],
                    configAsync.valueOrNull,
                    ref.watch(moneyFormatProvider),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Faixa vermelha no topo da lista com as fichas cujo custo está incompleto
  /// (linhas por ligar ou ingredientes sem preço, em qualquer nível).
  Widget _avisoPrecoEmFalta(List<FichaTecnica>? todas) {
    final afetadas = [
      for (final f in todas ?? const <FichaTecnica>[])
        if (f.custoSemDados.isNotEmpty) f,
    ];
    if (afetadas.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final n = afetadas.length;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.euro_outlined, size: 18, color: cs.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n == 1
                      ? 'Preço em falta em 1 ficha — o custo fica errado'
                      : 'Preço em falta em $n fichas — o custo fica errado',
                  style: TextStyle(
                    color: cs.onErrorContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  afetadas.map((f) => f.nome).join(', '),
                  style: TextStyle(color: cs.onErrorContainer),
                ),
                Text(
                  'Abre a ficha para ver o que falta (ingrediente sem preço '
                  'ou por ligar).',
                  style: TextStyle(color: cs.onErrorContainer, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(FichaTecnica f, CostConfig? config, MoneyFmt fmt) {
    if (_trash) {
      return ListTile(
        title: Text(f.nome),
        subtitle: f.categoria.isEmpty ? null : Text(f.categoria),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Restaurar',
              icon: const Icon(Icons.restore),
              onPressed: _busy
                  ? null
                  : () => _run(
                      () => ref.read(fichaActionsProvider).restore(f.id),
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
                        mensagem: 'Remove a ficha e as suas linhas.',
                        confirmar: 'Apagar',
                        destrutivo: true,
                      );
                      if (ok) {
                        await _run(
                          () => ref
                              .read(fichaActionsProvider)
                              .deleteForever(f.id),
                        );
                      }
                    },
            ),
          ],
        ),
      );
    }

    // compara-se com o preço de venda ao público: com IVA
    final preco = config?.precoSugeridoComIva(f.custoProduto);
    final formatosTodos = f.formatoId.isEmpty
        ? null
        : ref.watch(formatosProvider).valueOrNull;
    final formatoNome = formatosTodos == null
        ? null
        : [
            for (final x in formatosTodos)
              if (x.id == f.formatoId) x.nome,
          ].join();
    final subtitle = [
      if (f.categoria.isNotEmpty) f.categoria,
      if (formatoNome != null && formatoNome.isNotEmpty) formatoNome,
      if (f.pesoProduto > 0) '${f.pesoProduto.toStringAsFixed(0)} g',
    ].join(' · ');

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final semPreco = f.custoSemDados.isNotEmpty;
    final faltaInfo = pendenciasProduto(f);

    final tile = ListTile(
      title: Row(
        children: [
          Flexible(child: Text(f.nome)),
          if (faltaInfo.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Tooltip(
                message:
                    'Informação do produto por completar: '
                    '${faltaInfo.join(' · ')}',
                child: Icon(
                  Icons.local_dining_outlined,
                  size: 16,
                  color: cs.error,
                ),
              ),
            ),
        ],
      ),
      subtitle: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(subtitle.isEmpty ? 'custo ' : '$subtitle · custo '),
          Text(
            fmt(f.custoProduto),
            style: semPreco
                ? TextStyle(color: cs.error, fontWeight: FontWeight.bold)
                : null,
          ),
          if (semPreco) ...[
            const SizedBox(width: 2),
            PendenciaAviso(
              mensagem:
                  'Este custo não é definitivo: falta o preço (ou a ligação '
                  'a um ingrediente) de ${f.custoSemDados.map((x) => x.nome).join(', ')}.',
            ),
          ],
        ],
      ),
      trailing: SizedBox(
        width: 104,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (preco != null)
              Text(
                'sugerido ${fmt(preco)}',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            InkWell(
              onTap: _podeEditar ? () => _editarPrecoVenda(f) : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'venda ${f.temPrecoVenda ? fmt(f.precoVenda) : '—'}',
                    style: tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                  if (_podeEditar) ...[
                    const SizedBox(width: 3),
                    Icon(Icons.edit_outlined, size: 13, color: cs.primary),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      onTap: () => context.go('${Routes.techSheets}/${f.id}'),
      onLongPress: _podeEditar
          ? () => _run(() => ref.read(fichaActionsProvider).duplicate(f.id))
          : null,
    );

    if (!_podeEditar) return tile;

    return SwipeToDelete(
      key: ValueKey(f.id),
      confirmar: () => confirmDialog(
        context,
        titulo: 'Mover para a lixeira',
        mensagem: 'Mover "${f.nome}" para a lixeira?',
        confirmar: 'Mover',
      ),
      apagar: () =>
          _run(() => ref.read(fichaActionsProvider).moveToTrash(f.id)),
      child: tile,
    );
  }
}
