import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/formatting/money_provider.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/help_actions.dart';
import '../../../core/widgets/history_sheet.dart';
import '../../pricing/data/cost_config_repository.dart';
import '../../pricing/domain/cost_config.dart';
import '../../recipes/presentation/item_picker_sheet.dart';
import '../application/tech_sheets_providers.dart';
import '../domain/tech_sheet.dart';
import '../domain/tech_sheet_item.dart';
import 'declaracao_nutricional_sheet.dart';
import 'ficha_form_sheet.dart';

class TechSheetDetailScreen extends ConsumerStatefulWidget {
  const TechSheetDetailScreen({super.key, required this.fichaId});
  final String fichaId;

  @override
  ConsumerState<TechSheetDetailScreen> createState() =>
      _TechSheetDetailScreenState();
}

class _TechSheetDetailScreenState
    extends ConsumerState<TechSheetDetailScreen> {
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

  Future<void> _addTo(SlotFicha slot) async {
    final picked = await showItemPickerSheet(
      context,
      apenasEmbalagem: slot == SlotFicha.embalagem,
    );
    if (picked == null) return;
    await _run(
      () => ref.read(fichaActionsProvider).addItem(
            fichaId: widget.fichaId,
            slot: slot,
            ingredienteId:
                picked.kind == PickedKind.ingrediente ? picked.id : null,
            receitaId:
                picked.kind == PickedKind.subReceita ? picked.id : null,
            embalagemId:
                picked.kind == PickedKind.embalagem ? picked.id : null,
            kitId: picked.kind == PickedKind.kit ? picked.id : null,
            quantidadeG: picked.quantidadeG,
          ),
    );
  }

  Future<void> _editQty(ItemFicha item) async {
    final ctrl =
        TextEditingController(text: item.quantidadeG.toStringAsFixed(0));
    final novo = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Quantidade — ${item.nome}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: item.isKit
                ? 'Kits'
                : item.isEmbalagem
                    ? 'Peças'
                    : 'Gramas',
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
    if (novo == null || novo <= 0) return;
    await _run(
      () => ref
          .read(fichaActionsProvider)
          .setQuantidade(widget.fichaId, item.id, novo),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(fichaDetailProvider(widget.fichaId));
    final config = ref.watch(costConfigProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.techSheets),
        ),
        title: Text(
          detailAsync.maybeWhen(
            data: (d) => d.ficha.nome,
            orElse: () => 'Ficha',
          ),
        ),
        actions: [
          const HelpActions(topic: HelpTopic.fichaDetalhe),
          detailAsync.maybeWhen(
            data: (d) => IconButton(
              tooltip: 'Declaração nutricional',
              icon: const Icon(Icons.local_dining_outlined),
              onPressed: () =>
                  showDeclaracaoNutricionalSheet(context, ficha: d.ficha),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          detailAsync.maybeWhen(
            data: (d) => IconButton(
              tooltip: 'Histórico',
              icon: const Icon(Icons.history),
              onPressed: () => showHistorySheet(
                context,
                tipo: 'ficha',
                id: widget.fichaId,
                titulo: d.ficha.nome,
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          if (_podeEditar)
            detailAsync.maybeWhen(
              data: (d) => IconButton(
                tooltip: 'Editar ficha',
                icon: const Icon(Icons.edit_outlined),
                onPressed: _busy
                    ? null
                    : () async {
                        final input = await showFichaFormSheet(
                          context,
                          existente: d.ficha,
                        );
                        if (input == null) return;
                        await _run(
                          () => ref
                              .read(fichaActionsProvider)
                              .update(widget.fichaId, input),
                        );
                      },
              ),
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
      body: AsyncValueView<FichaDetail>(
        value: detailAsync,
        onRetry: () => ref.invalidate(fichaDetailProvider(widget.fichaId)),
        data: (d) {
          final fmt = ref.watch(moneyFormatProvider);
          return ListView(
          children: [
            if (_busy) const LinearProgressIndicator(),
            _Header(detail: d, config: config, fmt: fmt),
            const Divider(height: 1),
            for (final slot in SlotFicha.values)
              _SlotSection(
                slot: slot,
                itens: d.porSlot[slot] ?? const [],
                detail: d,
                podeEditar: _podeEditar,
                onAdd: () => _addTo(slot),
                onEditQty: _editQty,
                onRemove: (item) => _run(
                  () => ref
                      .read(fichaActionsProvider)
                      .removeItem(widget.fichaId, item.id),
                ),
                fmt: fmt,
              ),
            if (config != null)
              _PriceBreakdown(custo: d.custoPreview, config: config, fmt: fmt),
            const SizedBox(height: 24),
          ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.detail, required this.fmt, this.config});
  final FichaDetail detail;
  final MoneyFmt fmt;
  final CostConfig? config;

  @override
  Widget build(BuildContext context) {
    Widget cell(String t, String v, {Color? color}) => Column(
          children: [
            Text(t, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(
              v,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: color,
              ),
            ),
          ],
        );

    final preco = config?.precoSugerido(detail.custoPreview);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          cell('Peso', '${detail.pesoTotal.toStringAsFixed(0)} g'),
          cell('Custo', fmt(detail.custoPreview)),
          if (preco != null)
            cell(
              'Preço sugerido',
              fmt(preco),
              color: Theme.of(context).colorScheme.primary,
            ),
        ],
      ),
    );
  }
}

class _SlotSection extends StatelessWidget {
  const _SlotSection({
    required this.slot,
    required this.itens,
    required this.detail,
    required this.podeEditar,
    required this.onAdd,
    required this.onEditQty,
    required this.onRemove,
    required this.fmt,
  });

  final MoneyFmt fmt;

  final SlotFicha slot;
  final List<ItemFicha> itens;
  final FichaDetail detail;
  final bool podeEditar;
  final VoidCallback onAdd;
  final void Function(ItemFicha) onEditQty;
  final void Function(ItemFicha) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  slot.label,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: Theme.of(context).colorScheme.primary),
                ),
              ),
              if (podeEditar)
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Adicionar'),
                ),
            ],
          ),
        ),
        if (itens.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('—'),
          )
        else
          for (final item in itens)
            ListTile(
              dense: true,
              title: Text(item.nome),
              subtitle: Text(
                item.isKit
                    ? '${item.quantidadeG.toStringAsFixed(0)} kit · '
                        '${fmt(item.custoLinha)}'
                    : item.isEmbalagem
                        ? '${item.quantidadeG.toStringAsFixed(0)} pç · '
                            '${fmt(item.custoLinha)}'
                        : '${item.quantidadeG.toStringAsFixed(0)} g · '
                            '${detail.percentagem(item).toStringAsFixed(1)}% · '
                            '${fmt(item.custoLinha)}',
              ),
              onTap: podeEditar ? () => onEditQty(item) : null,
              trailing: podeEditar
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => onRemove(item),
                    )
                  : null,
            ),
        const Divider(height: 1),
      ],
    );
  }
}

class _PriceBreakdown extends StatelessWidget {
  const _PriceBreakdown({
    required this.custo,
    required this.config,
    required this.fmt,
  });
  final double custo;
  final CostConfig config;
  final MoneyFmt fmt;

  @override
  Widget build(BuildContext context) {
    final quebra = config.quebra(custo);
    final preco = config.precoSugerido(custo);
    return ExpansionTile(
      title: const Text('Quebra do preço'),
      subtitle: Text(
        config.cmvPercent <= 0
            ? 'Percentuais somam ≥ 100% — ajusta em Configurações'
            : 'CMV ${config.cmvPercent.toStringAsFixed(1)}%',
      ),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        for (final e in quebra.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(e.key),
                Text(fmt(e.value)),
              ],
            ),
          ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PREÇO FINAL',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                fmt(preco),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
