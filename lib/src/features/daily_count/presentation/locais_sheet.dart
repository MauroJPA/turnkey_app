import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../invoices/domain/invoice_erros.dart';
import '../../sales/domain/venda.dart' show canaisVenda;
import '../application/contagem_providers.dart';
import '../domain/local.dart';

/// Gerir os locais: a loja, Alvalade, as plataformas… e os canais de venda de
/// cada um.
Future<void> showLocaisSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => const _Sheet(),
  );
}

class _Sheet extends ConsumerWidget {
  const _Sheet();

  Future<void> _editar(
    BuildContext context,
    WidgetRef ref, {
    Local? existente,
  }) async {
    final input = await showDialog<LocalInput>(
      context: context,
      builder: (_) => _LocalDialog(existente: existente),
    );
    if (input == null) return;
    try {
      final acoes = ref.read(contagemActionsProvider);
      if (existente == null) {
        await acoes.criarLocal(input);
      } else {
        await acoes.atualizarLocal(existente.id, input);
      }
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final locais = ref.watch(todosLocaisProvider).valueOrNull ?? const [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Locais', style: tt.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Cada local tem a sua contagem. Os canais de venda dizem que '
              'vendas saem de cada local (ex.: "Parceria Alvalade" → Alvalade). '
              'Vendas de canais que não estão em nenhum local contam para a loja.',
              style: tt.bodySmall,
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final l in locais)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(switch (l.tipo) {
                        TipoLocal.loja => Icons.storefront_outlined,
                        TipoLocal.parceiro => Icons.handshake_outlined,
                        TipoLocal.plataforma => Icons.delivery_dining_outlined,
                      }),
                      title: Text(
                        l.arquivado ? '${l.nome} (arquivado)' : l.nome,
                      ),
                      subtitle: Text(
                        l.canais.isEmpty
                            ? l.tipo.label
                            : '${l.tipo.label} · ${l.canais.join(', ')}',
                      ),
                      onTap: () => _editar(context, ref, existente: l),
                      trailing: IconButton(
                        tooltip: l.arquivado ? 'Reativar' : 'Arquivar',
                        icon: Icon(
                          l.arquivado
                              ? Icons.unarchive_outlined
                              : Icons.archive_outlined,
                        ),
                        onPressed: () => ref
                            .read(contagemActionsProvider)
                            .arquivarLocal(l.id, arquivado: !l.arquivado),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _editar(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Novo local'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalDialog extends StatefulWidget {
  const _LocalDialog({this.existente});
  final Local? existente;

  @override
  State<_LocalDialog> createState() => _LocalDialogState();
}

class _LocalDialogState extends State<_LocalDialog> {
  late final _nome = TextEditingController(text: widget.existente?.nome ?? '');
  late final _canais = TextEditingController(
    text: widget.existente?.canais.join(', ') ?? '',
  );
  late TipoLocal _tipo = widget.existente?.tipo ?? TipoLocal.parceiro;
  String? _erro;

  @override
  void dispose() {
    _nome.dispose();
    _canais.dispose();
    super.dispose();
  }

  void _guardar() {
    final nome = _nome.text.trim();
    if (nome.isEmpty) {
      setState(() => _erro = 'Dá um nome ao local.');
      return;
    }
    final canais = [
      for (final c in _canais.text.split(','))
        if (c.trim().isNotEmpty) c.trim(),
    ];
    Navigator.pop(
      context,
      LocalInput(
        nome: nome,
        tipo: _tipo,
        canais: canais,
        ordem: widget.existente?.ordem ?? 99,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existente == null ? 'Novo local' : 'Editar local'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nome,
                autofocus: widget.existente == null,
                decoration: InputDecoration(
                  labelText: 'Nome',
                  errorText: _erro,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<TipoLocal>(
                initialValue: _tipo,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: [
                  for (final t in TipoLocal.values)
                    DropdownMenuItem(value: t, child: Text(t.label)),
                ],
                onChanged: (v) => setState(() => _tipo = v ?? _tipo),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _canais,
                decoration: InputDecoration(
                  labelText: 'Canais de venda deste local',
                  helperText:
                      'Separados por vírgula. Ex.: ${canaisVenda.take(3).join(', ')}',
                  helperMaxLines: 2,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}
