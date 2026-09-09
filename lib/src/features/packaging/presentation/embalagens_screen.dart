import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/formatting/money_provider.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/help_actions.dart';
import '../application/embalagem_providers.dart';
import '../domain/embalagem.dart';

class EmbalagensScreen extends ConsumerWidget {
  const EmbalagensScreen({super.key});

  bool _podeEditar(WidgetRef ref) =>
      ref.read(currentPapelProvider).canEditBusiness;

  Future<void> _form(BuildContext context, WidgetRef ref,
      {Embalagem? existente}) async {
    final input = await showModalBottomSheet<EmbalagemInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EmbalagemForm(existente: existente),
    );
    if (input == null) return;
    final a = ref.read(embalagemActionsProvider);
    try {
      if (existente == null) {
        await a.criar(input);
      } else {
        await a.atualizar(existente.id, input);
      }
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(embalagensListProvider);
    final fmt = ref.watch(moneyFormatProvider);
    final podeEditar = _podeEditar(ref);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
        title: const Text('Embalagens'),
        actions: const [HelpActions(topic: HelpTopic.embalagens)],
      ),
      floatingActionButton: podeEditar
          ? FloatingActionButton.extended(
              onPressed: () => _form(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Embalagem'),
            )
          : null,
      body: AsyncValueView<List<Embalagem>>(
        value: async,
        onRetry: () => ref.invalidate(embalagensListProvider),
        data: (itens) {
          if (itens.isEmpty) {
            return const EmptyState(
              icon: Icons.inventory_2_outlined,
              titulo: 'Sem embalagens',
              mensagem: 'Caixas, sacos, saquetas, adesivos, fita… com o custo, '
                  'para entrar nas fichas técnicas.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: itens.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final e = itens[i];
              final sub = [
                if (e.tipo.isNotEmpty) e.tipo,
                'compra ${fmt(e.precoCompra)} / ${_n(e.unidadesCompra)} pç',
                if (e.rendeUnidades > 1)
                  'rende ${_n(e.rendeUnidades)} un',
                if (e.fornecedor.isNotEmpty) e.fornecedor,
              ].join(' · ');
              return ListTile(
                title: Text(e.nome),
                subtitle: Text(sub),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(fmt(e.custoUnidade),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('por unidade',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                onTap: podeEditar
                    ? () => _form(context, ref, existente: e)
                    : null,
                onLongPress: podeEditar
                    ? () async {
                        final ok = await confirmDialog(
                          context,
                          titulo: 'Apagar embalagem?',
                          mensagem:
                              'Remove "${e.nome}". As fichas que a usam perdem '
                              'esse custo.',
                          confirmar: 'Apagar',
                          destrutivo: true,
                        );
                        if (ok) {
                          await ref
                              .read(embalagemActionsProvider)
                              .apagar(e.id);
                        }
                      }
                    : null,
              );
            },
          );
        },
      ),
    );
  }

  static String _n(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';
}

class _EmbalagemForm extends StatefulWidget {
  const _EmbalagemForm({this.existente});
  final Embalagem? existente;

  @override
  State<_EmbalagemForm> createState() => _EmbalagemFormState();
}

class _EmbalagemFormState extends State<_EmbalagemForm> {
  late final _nome =
      TextEditingController(text: widget.existente?.nome ?? '');
  late final _forn =
      TextEditingController(text: widget.existente?.fornecedor ?? '');
  late final _preco = TextEditingController(
    text: widget.existente == null
        ? ''
        : _s(widget.existente!.precoCompra),
  );
  late final _pecas = TextEditingController(
    text: widget.existente == null
        ? '1'
        : _s(widget.existente!.unidadesCompra),
  );
  late final _rende = TextEditingController(
    text: widget.existente == null
        ? '1'
        : _s(widget.existente!.rendeUnidades),
  );
  late String _tipo = widget.existente?.tipo.isNotEmpty == true
      ? widget.existente!.tipo
      : 'Caixa';

  static String _s(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';
  double _num(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.').trim()) ?? 0;

  @override
  void dispose() {
    for (final c in [_nome, _forn, _preco, _pecas, _rende]) {
      c.dispose();
    }
    super.dispose();
  }

  void _guardar() {
    if (_nome.text.trim().isEmpty) return;
    Navigator.pop(
      context,
      EmbalagemInput(
        nome: _nome.text,
        tipo: _tipo,
        precoCompra: _num(_preco),
        unidadesCompra: _num(_pecas),
        rendeUnidades: _num(_rende),
        fornecedor: _forn.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final custoUn = (_num(_preco) / (_num(_pecas) <= 0 ? 1 : _num(_pecas))) /
        (_num(_rende) <= 0 ? 1 : _num(_rende));
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existente == null ? 'Nova embalagem' : 'Editar embalagem',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nome,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nome *',
                hintText: 'Ex.: Caixa 6 un, Saco kraft, Adesivo 4 cm',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _tipo,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: [
                for (final t in kTiposEmbalagem)
                  DropdownMenuItem(value: t, child: Text(t)),
              ],
              onChanged: (v) => setState(() => _tipo = v ?? 'Caixa'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _preco,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Preço da compra',
                      prefixText: '€ ',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _pecas,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Peças na compra',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rende,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Uma peça embala quantas unidades?',
                hintText: '1 saco = 1 un; 1 caixa = 6 un',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _forn,
              decoration: const InputDecoration(labelText: 'Fornecedor'),
            ),
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Custo por unidade de produto: '
                  '€ ${custoUn.toStringAsFixed(4)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _guardar,
              child: Text(widget.existente == null ? 'Adicionar' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
