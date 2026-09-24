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
import '../../cookie_formats/application/cookie_format_providers.dart';
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

class _TechSheetDetailScreenState extends ConsumerState<TechSheetDetailScreen> {
  bool _busy = false;

  bool get _podeEditar => ref.read(currentPapelProvider).canEditBusiness;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
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

  Future<void> _addTo(SlotFicha slot) async {
    final picked = await showItemPickerSheet(
      context,
      apenasEmbalagem: slot == SlotFicha.embalagem,
    );
    if (picked == null) return;
    await _run(
      () => ref
          .read(fichaActionsProvider)
          .addItem(
            fichaId: widget.fichaId,
            slot: slot,
            ingredienteId: picked.kind == PickedKind.ingrediente
                ? picked.id
                : null,
            receitaId: picked.kind == PickedKind.subReceita ? picked.id : null,
            embalagemId: picked.kind == PickedKind.embalagem ? picked.id : null,
            kitId: picked.kind == PickedKind.kit ? picked.id : null,
            quantidadeG: picked.quantidadeG,
          ),
    );
  }

  Future<void> _editQty(ItemFicha item) async {
    final ctrl = TextEditingController(
      text: item.quantidadeG.toStringAsFixed(0),
    );
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

  Future<void> _editarPreco(FichaTecnica ficha) async {
    final ctrl = TextEditingController(
      text: ficha.precoVenda > 0 ? ficha.precoVenda.toStringAsFixed(2) : '',
    );
    final novo = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Preço de venda'),
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
    if (novo == null || novo == ficha.precoVenda) return;
    await _run(
      () => ref
          .read(fichaActionsProvider)
          .setPrecoVenda(widget.fichaId, novo < 0 ? 0 : novo),
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
          final formatos = ref.watch(formatosProvider).valueOrNull;
          final formatoNome = (formatos == null || d.ficha.formatoId.isEmpty)
              ? ''
              : [
                  for (final f in formatos)
                    if (f.id == d.ficha.formatoId) f.rotulo,
                ].join();
          return ListView(
            children: [
              if (_busy) const LinearProgressIndicator(),
              if (formatoNome.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(
                    children: [
                      const Icon(Icons.cookie_outlined, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Formato: $formatoNome',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              _Header(
                detail: d,
                config: config,
                fmt: fmt,
                podeEditar: _podeEditar,
                onEditarPreco: _busy ? null : () => _editarPreco(d.ficha),
              ),
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
                _PriceBreakdown(
                  custo: d.custoPreview,
                  config: config,
                  fmt: fmt,
                  precoVenda: d.ficha.precoVenda,
                  cmvReal: d.ficha.cmvRealPercent(d.custoPreview),
                ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.detail,
    required this.fmt,
    required this.podeEditar,
    this.config,
    this.onEditarPreco,
  });
  final FichaDetail detail;
  final MoneyFmt fmt;
  final CostConfig? config;
  final bool podeEditar;
  final VoidCallback? onEditarPreco;

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

    final ficha = detail.ficha;
    final sugerido = config?.precoSugerido(detail.custoPreview);
    final cmvEsperado = (config != null && config!.cmvPercent > 0)
        ? config!.cmvPercent
        : null;
    final cmvReal = ficha.cmvRealPercent(detail.custoPreview);
    final cs = Theme.of(context).colorScheme;
    final Color? corReal = cmvReal == null || cmvEsperado == null
        ? null
        : (cmvReal <= cmvEsperado ? cs.primary : cs.error);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              cell('Peso', '${detail.pesoTotal.toStringAsFixed(0)} g'),
              cell('Custo', fmt(detail.custoPreview)),
              if (sugerido != null && !ficha.temPrecoVenda)
                cell(
                  'Preço sugerido',
                  fmt(sugerido),
                  color: Theme.of(context).colorScheme.primary,
                ),
              InkWell(
                onTap: podeEditar ? onEditarPreco : null,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Preço de venda',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (podeEditar) ...[
                            const SizedBox(width: 2),
                            Icon(
                              Icons.edit,
                              size: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ficha.temPrecoVenda ? fmt(ficha.precoVenda) : 'Definir',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: ficha.temPrecoVenda
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.error,
                        ),
                      ),
                      if (ficha.temPrecoVenda)
                        Text(
                          'margem ${ficha.margemPercent.toStringAsFixed(0)}%',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              cell(
                'CMV esperado',
                cmvEsperado == null
                    ? '—'
                    : '${cmvEsperado.toStringAsFixed(1)}%',
              ),
              cell(
                'CMV real',
                cmvReal == null
                    ? 'defina o preço'
                    : '${cmvReal.toStringAsFixed(1)}%',
                color: corReal,
              ),
            ],
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
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
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
    this.precoVenda = 0,
    this.cmvReal,
  });
  final double custo;
  final double precoVenda;
  final double? cmvReal;
  final CostConfig config;
  final MoneyFmt fmt;

  static String _pct(double v) => '${v.toStringAsFixed(1)}%';

  Widget _celula(
    BuildContext context,
    double? valor,
    double? pct, {
    bool negrito = false,
    Color? cor,
  }) {
    final tt = Theme.of(context).textTheme;
    if (valor == null) {
      return SizedBox(
        width: 92,
        child: Text('—', textAlign: TextAlign.end, style: tt.bodyMedium),
      );
    }
    final estilo = TextStyle(
      fontWeight: negrito ? FontWeight.bold : null,
      color: cor,
    );
    return SizedBox(
      width: 92,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(fmt(valor), style: estilo),
          if (pct != null)
            Text(
              _pct(pct),
              style: tt.bodySmall?.copyWith(color: cor),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final q = config.quebraComparada(custo, precoVenda);
    final semReal = q.precoReal == null;
    return ExpansionTile(
      title: const Text('Quebra do preço'),
      subtitle: Text(
        config.cmvPercent <= 0
            ? 'Percentuais somam ≥ 100% — ajusta em Configurações'
            : 'CMV esperado ${config.cmvPercent.toStringAsFixed(1)}%'
                '${cmvReal == null ? '' : ' · real ${cmvReal!.toStringAsFixed(1)}%'}',
      ),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              const Expanded(child: SizedBox.shrink()),
              SizedBox(
                width: 92,
                child: Text('Esperado',
                    textAlign: TextAlign.end, style: tt.labelMedium),
              ),
              SizedBox(
                width: 92,
                child: Text('Real',
                    textAlign: TextAlign.end, style: tt.labelMedium),
              ),
            ],
          ),
        ),
        for (final l in q.linhas)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(l.nome)),
                _celula(context, l.esperado, l.esperadoPct),
                _celula(
                  context,
                  l.real,
                  l.realPct,
                  cor: (l.real != null && l.real! < 0) ? cs.error : null,
                ),
              ],
            ),
          ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'PREÇO FINAL',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              _celula(context, q.precoEsperado, 100, negrito: true),
              _celula(context, q.precoReal, semReal ? null : 100,
                  negrito: true),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(
            semReal
                ? 'Define o preço de venda para ver a coluna Real.'
                : 'Esperado = preço sugerido pelos percentuais. Real = o preço '
                    'de venda que praticas: a matéria-prima é o custo verdadeiro '
                    'e a margem de lucro é o que sobra.',
            style: tt.bodySmall,
          ),
        ),
      ],
    );
  }
}
