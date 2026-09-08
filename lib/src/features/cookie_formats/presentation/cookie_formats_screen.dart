import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/help/help_content.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/help_button.dart';
import '../application/cookie_format_providers.dart';
import '../domain/cookie_format.dart';

class CookieFormatsScreen extends ConsumerWidget {
  const CookieFormatsScreen({super.key});

  bool _podeEditar(WidgetRef ref) =>
      ref.read(currentPapelProvider).canEditConfig;

  Future<void> _editar(
    BuildContext context,
    WidgetRef ref, {
    FormatoCookie? existente,
  }) async {
    final input = await showModalBottomSheet<FormatoInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FormatoSheet(existente: existente),
    );
    if (input == null) return;
    final actions = ref.read(cookieFormatActionsProvider);
    try {
      if (existente == null) {
        await actions.criar(input);
      } else {
        await actions.editar(existente.id, input);
      }
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _apagar(
    BuildContext context,
    WidgetRef ref,
    FormatoCookie f,
  ) async {
    final ok = await confirmDialog(
      context,
      titulo: 'Apagar formato?',
      mensagem: 'Remove "${f.nome}". Produções antigas mantêm o valor guardado.',
      confirmar: 'Apagar',
      destrutivo: true,
    );
    if (!ok) return;
    try {
      await ref.read(cookieFormatActionsProvider).apagar(f.id);
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(formatosProvider);
    final podeEditar = _podeEditar(ref);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.settings),
        ),
        title: const Text('Formatos de cookie'),
        actions: const [HelpButton(topic: HelpTopic.formatos)],
      ),
      floatingActionButton: podeEditar
          ? FloatingActionButton.extended(
              onPressed: () => _editar(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Formato'),
            )
          : null,
      body: AsyncValueView<List<FormatoCookie>>(
        value: async,
        onRetry: () => ref.invalidate(formatosProvider),
        data: (fs) {
          if (fs.isEmpty) {
            return const EmptyState(
              icon: Icons.cookie_outlined,
              titulo: 'Sem formatos',
              mensagem: 'Use "+" para criar o primeiro formato de cookie.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: fs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final f = fs[i];
              return ListTile(
                title: Text(f.nome),
                subtitle: Text(
                  f.temRecheio
                      ? 'massa ${f.massaG.toStringAsFixed(0)} g + recheio '
                          '${f.recheioG.toStringAsFixed(0)} g = '
                          '${f.totalG.toStringAsFixed(0)} g'
                      : 'massa ${f.massaG.toStringAsFixed(0)} g',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!f.ativo)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Chip(label: Text('inativo')),
                      ),
                    if (podeEditar)
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Remover formato',
                        onPressed: () => _apagar(context, ref, f),
                      ),
                  ],
                ),
                onTap: podeEditar
                    ? () => _editar(context, ref, existente: f)
                    : null,
                onLongPress:
                    podeEditar ? () => _apagar(context, ref, f) : null,
              );
            },
          );
        },
      ),
    );
  }
}

class _FormatoSheet extends StatefulWidget {
  const _FormatoSheet({this.existente});
  final FormatoCookie? existente;

  @override
  State<_FormatoSheet> createState() => _FormatoSheetState();
}

class _FormatoSheetState extends State<_FormatoSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nome =
      TextEditingController(text: widget.existente?.nome ?? '');
  late final _massa = TextEditingController(
    text: widget.existente?.massaG.toStringAsFixed(0) ?? '',
  );
  late final _recheio = TextEditingController(
    text: (widget.existente?.recheioG ?? 0) > 0
        ? widget.existente!.recheioG.toStringAsFixed(0)
        : '',
  );
  late final _ordem = TextEditingController(
    text: (widget.existente?.ordem ?? 0).toStringAsFixed(0),
  );
  late bool _ativo = widget.existente?.ativo ?? true;

  @override
  void dispose() {
    _nome.dispose();
    _massa.dispose();
    _recheio.dispose();
    _ordem.dispose();
    super.dispose();
  }

  double _num(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.').trim()) ?? 0;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      FormatoInput(
        nome: _nome.text,
        massaG: _num(_massa),
        recheioG: _num(_recheio),
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
              widget.existente == null ? 'Novo formato' : 'Editar formato',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nome,
              decoration: const InputDecoration(labelText: 'Nome *'),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _massa,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Massa por cookie (g) *',
              ),
              validator: (v) {
                final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                return (n == null || n <= 0) ? 'Tem de ser > 0' : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _recheio,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Recheio por cookie (g)',
                helperText: 'Deixa vazio se o formato não leva recheio.',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ordem,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Ordem'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ativo'),
              value: _ativo,
              onChanged: (v) => setState(() => _ativo = v),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _submit,
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
