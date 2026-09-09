import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/money_provider.dart';
import '../../../core/widgets/async_value_view.dart';
import '../application/embalagem_kit_providers.dart';
import '../application/embalagem_providers.dart';
import '../domain/embalagem.dart';
import '../domain/embalagem_kit.dart';

/// Editor de um kit de embalagens: nome, descrição e as linhas
/// (embalagem + quantidade). O custo do kit é a soma das linhas.
Future<void> showKitEditorSheet(
  BuildContext context, {
  required String kitId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _KitEditorSheet(kitId: kitId),
  );
}

class _KitEditorSheet extends ConsumerStatefulWidget {
  const _KitEditorSheet({required this.kitId});
  final String kitId;

  @override
  ConsumerState<_KitEditorSheet> createState() => _KitEditorSheetState();
}

class _KitEditorSheetState extends ConsumerState<_KitEditorSheet> {
  final _nome = TextEditingController();
  final _descricao = TextEditingController();
  bool _preencheu = false;
  bool _busy = false;

  @override
  void dispose() {
    _nome.dispose();
    _descricao.dispose();
    super.dispose();
  }

  Future<void> _guardarCabecalho(EmbalagemKit kit) async {
    final nome = _nome.text.trim().isEmpty ? kit.nome : _nome.text.trim();
    final descricao = _descricao.text.trim();
    if (nome == kit.nome && descricao == kit.descricao) return;
    setState(() => _busy = true);
    try {
      await ref.read(embalagemKitActionsProvider).atualizar(
            kit.id,
            EmbalagemKitInput(nome: nome, descricao: descricao),
          );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _adicionarLinha() async {
    final embs = ref.read(embalagensListProvider).valueOrNull ?? const [];
    if (embs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cria primeiro as embalagens no separador "Peças".'),
        ),
      );
      return;
    }
    final emb = await showDialog<Embalagem>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Escolher embalagem'),
        children: [
          for (final e in embs)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, e),
              child: Text(
                '${e.nome}'
                '${e.tipo.isEmpty ? '' : '  ·  ${e.tipo}'}',
              ),
            ),
        ],
      ),
    );
    if (emb == null || !mounted) return;
    final qtd = await _pedirQtd(emb.nome, 1);
    if (qtd == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(embalagemKitActionsProvider)
          .adicionarItem(widget.kitId, emb.id, qtd);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<double?> _pedirQtd(String nome, double inicial) {
    final ctrl = TextEditingController(text: _fmtNum(inicial));
    return showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Quantidade — $nome'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Peças no kit'),
          onSubmitted: (_) =>
              Navigator.pop(ctx, double.tryParse(ctrl.text.replaceAll(',', '.'))),
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
  }

  static String _fmtNum(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';

  @override
  Widget build(BuildContext context) {
    final fmt = ref.watch(moneyFormatProvider);
    final async = ref.watch(embalagemKitDetailProvider(widget.kitId));

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: AsyncValueView<KitDetalhe>(
        value: async,
        onRetry: () =>
            ref.invalidate(embalagemKitDetailProvider(widget.kitId)),
        data: (d) {
          if (!_preencheu) {
            _nome.text = d.kit.nome;
            _descricao.text = d.kit.descricao;
            _preencheu = true;
          }
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Kit de embalagens',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                TextField(
                  controller: _nome,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Nome *'),
                  onEditingComplete: () => _guardarCabecalho(d.kit),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descricao,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Descrição',
                    hintText: 'Ex.: 1 saqueta + 1 caixa + 1 saco + 2 adesivos',
                  ),
                  onEditingComplete: () => _guardarCabecalho(d.kit),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _busy ? null : () => _guardarCabecalho(d.kit),
                    child: const Text('Guardar nome/descrição'),
                  ),
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text('Embalagens no kit',
                          style: Theme.of(context).textTheme.titleSmall),
                    ),
                    TextButton.icon(
                      onPressed: _busy ? null : _adicionarLinha,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Adicionar'),
                    ),
                  ],
                ),
                if (d.itens.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Ainda sem embalagens neste kit.'),
                  )
                else
                  for (final it in d.itens)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(it.nome),
                      subtitle: Text(
                        '${_fmtNum(it.quantidade)} pç · ${fmt(it.custoLinha)}',
                      ),
                      onTap: _busy
                          ? null
                          : () async {
                              final q =
                                  await _pedirQtd(it.nome, it.quantidade);
                              if (q == null || q <= 0 || !mounted) return;
                              await ref
                                  .read(embalagemKitActionsProvider)
                                  .definirQuantidade(widget.kitId, it.id, q);
                            },
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: _busy
                            ? null
                            : () => ref
                                .read(embalagemKitActionsProvider)
                                .removerItem(widget.kitId, it.id),
                      ),
                    ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Custo por unidade de produto',
                        style: Theme.of(context).textTheme.titleSmall),
                    Text(
                      fmt(d.custoSoma),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    await _guardarCabecalho(d.kit);
                    if (mounted) nav.pop();
                  },
                  child: const Text('Concluído'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
