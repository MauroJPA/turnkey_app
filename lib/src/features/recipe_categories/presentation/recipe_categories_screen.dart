import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/help_actions.dart';
import '../application/categoria_receita_providers.dart';
import '../domain/categoria_receita.dart';

class RecipeCategoriesScreen extends ConsumerWidget {
  const RecipeCategoriesScreen({super.key});

  bool _podeEditar(WidgetRef ref) =>
      ref.read(currentPapelProvider).canEditConfig;

  Future<void> _editar(
    BuildContext context,
    WidgetRef ref, {
    CategoriaReceita? existente,
  }) async {
    final input = await showModalBottomSheet<CategoriaReceitaInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CategoriaSheet(existente: existente),
    );
    if (input == null) return;
    final actions = ref.read(categoriaReceitaActionsProvider);
    try {
      if (existente == null) {
        await actions.criar(input);
      } else {
        await actions.editar(existente.id, input);
      }
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _apagar(
    BuildContext context,
    WidgetRef ref,
    CategoriaReceita c,
  ) async {
    final ok = await confirmDialog(
      context,
      titulo: 'Apagar categoria?',
      mensagem:
          'Remove "${c.nome}". As receitas que já a usam mantêm o nome '
          'guardado; só deixa de aparecer para escolher em receitas novas.',
      confirmar: 'Apagar',
      destrutivo: true,
    );
    if (!ok) return;
    try {
      await ref.read(categoriaReceitaActionsProvider).apagar(c.id);
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(categoriasReceitaProvider);
    final podeEditar = _podeEditar(ref);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.settings),
        ),
        title: const Text('Categorias de receitas'),
        actions: const [HelpActions(topic: HelpTopic.categoriasReceita)],
      ),
      floatingActionButton: podeEditar
          ? FloatingActionButton.extended(
              onPressed: () => _editar(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Categoria'),
            )
          : null,
      body: AsyncValueView<List<CategoriaReceita>>(
        value: async,
        onRetry: () => ref.invalidate(categoriasReceitaProvider),
        data: (cs) {
          if (cs.isEmpty) {
            return const EmptyState(
              icon: Icons.label_outline,
              titulo: 'Sem categorias',
              mensagem: 'Use "+" para criar a primeira categoria de receitas.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: cs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final c = cs[i];
              return ListTile(
                title: Text(c.nome),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!c.ativo)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Chip(label: Text('inativa')),
                      ),
                    if (podeEditar)
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Remover categoria',
                        onPressed: () => _apagar(context, ref, c),
                      ),
                  ],
                ),
                onTap: podeEditar
                    ? () => _editar(context, ref, existente: c)
                    : null,
                onLongPress: podeEditar ? () => _apagar(context, ref, c) : null,
              );
            },
          );
        },
      ),
    );
  }
}

class _CategoriaSheet extends StatefulWidget {
  const _CategoriaSheet({this.existente});
  final CategoriaReceita? existente;

  @override
  State<_CategoriaSheet> createState() => _CategoriaSheetState();
}

class _CategoriaSheetState extends State<_CategoriaSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.existente?.nome ?? '');
  late final _ordem = TextEditingController(
    text: (widget.existente?.ordem ?? 0).toStringAsFixed(0),
  );
  late bool _ativo = widget.existente?.ativo ?? true;

  @override
  void dispose() {
    _nome.dispose();
    _ordem.dispose();
    super.dispose();
  }

  double _num(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.').trim()) ?? 0;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      CategoriaReceitaInput(
        nome: _nome.text,
        ordem: _num(_ordem),
        ativo: _ativo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existente == null ? 'Nova categoria' : 'Editar categoria',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nome,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nome *'),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ordem,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Ordem'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ativa'),
              subtitle: const Text(
                'Inativa: continua nas receitas que já a têm, mas não '
                'aparece para escolher numa receita nova.',
              ),
              value: _ativo,
              onChanged: (v) => setState(() => _ativo = v),
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: _submit, child: const Text('Guardar')),
          ],
        ),
      ),
    );
  }
}
