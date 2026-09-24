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
import '../../cookie_formats/application/cookie_format_providers.dart';
import '../../pricing/data/cost_config_repository.dart';
import '../../pricing/domain/cost_config.dart';
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
  bool _trash = false;
  bool _busy = false;

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
          decoration: const InputDecoration(labelText: 'Preço', prefixText: '€ '),
          onSubmitted: (_) => Navigator.pop(
              ctx, double.tryParse(ctrl.text.replaceAll(',', '.'))),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
                ctx, double.tryParse(ctrl.text.replaceAll(',', '.'))),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (novo == null || novo == f.precoVenda) return;
    await _run(
      () => ref.read(fichaActionsProvider).setPrecoVenda(f.id, novo < 0 ? 0 : novo),
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
        title: Text(_trash ? 'Fichas · Lixeira' : 'Fichas Técnicas'),
        actions: [
          const HelpActions(topic: HelpTopic.fichas),
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
          Expanded(
            child: AsyncValueView<List<FichaTecnica>>(
              value: listAsync,
              onRetry: () => ref.invalidate(fichasListProvider(_trash)),
              data: (all) {
                final items = all
                    .where((f) =>
                        _q.isEmpty ||
                        f.nome.toLowerCase().contains(_q.toLowerCase()))
                    .toList();
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

    final preco = config?.precoSugerido(f.custoProduto);
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
      'custo ${fmt(f.custoProduto)}',
    ].join(' · ');

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final tile = ListTile(
      title: Text(f.nome),
      subtitle: Text(subtitle),
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
                    style: tt.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.bold, color: cs.primary),
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

    return Dismissible(
      key: ValueKey(f.id),
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
        mensagem: 'Mover "${f.nome}" para a lixeira?',
        confirmar: 'Mover',
      ),
      onDismissed: (_) =>
          _run(() => ref.read(fichaActionsProvider).moveToTrash(f.id)),
      child: tile,
    );
  }
}
