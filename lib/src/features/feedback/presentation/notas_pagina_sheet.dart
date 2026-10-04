import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/current_user.dart';
import '../../../core/errors/mensagem_amigavel.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../application/nota_pagina_providers.dart';
import '../domain/nota_pagina.dart';

/// Notas de equipa desta página — diferente de "sugerir melhoria" (essa só a
/// equipa de desenvolvimento vê): qualquer pessoa da empresa vê e escreve,
/// para avisar colegas sem precisar de falar por fora da app. Marca-se como
/// resolvida quando já não faz falta.
void mostrarNotasPagina(BuildContext context, {required String pagina}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _NotasPaginaSheet(pagina: pagina),
  );
}

String _dataCurta(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _NotasPaginaSheet extends ConsumerStatefulWidget {
  const _NotasPaginaSheet({required this.pagina});
  final String pagina;

  @override
  ConsumerState<_NotasPaginaSheet> createState() => _NotasPaginaSheetState();
}

class _NotasPaginaSheetState extends ConsumerState<_NotasPaginaSheet> {
  final _ctrl = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _adicionar() async {
    final texto = _ctrl.text.trim();
    if (texto.isEmpty) return;
    setState(() => _enviando = true);
    try {
      await ref
          .read(notaPaginaActionsProvider)
          .criar(pagina: widget.pagina, texto: texto);
      _ctrl.clear();
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _apagar(NotaPagina n) async {
    final ok = await confirmDialog(
      context,
      titulo: 'Apagar nota?',
      mensagem: 'Remove esta nota para toda a equipa.',
      confirmar: 'Apagar',
      destrutivo: true,
    );
    if (!ok) return;
    try {
      await ref.read(notaPaginaActionsProvider).apagar(widget.pagina, n.id);
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notasPaginaProvider(widget.pagina));
    final papel = ref.watch(currentPapelProvider);
    final podeResolver = papel.canEditBusiness;
    final podeApagar = papel.canEditConfig;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Notas desta página',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Para avisar a equipa de algo nesta página (um problema, uma '
            'decisão, o que falta) sem precisar de falar por fora da app. '
            'Diferente do botão de sugestão/erro, que só a equipa de '
            'desenvolvimento lê.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: AsyncValueView<List<NotaPagina>>(
              value: async,
              onRetry: () => ref.invalidate(notasPaginaProvider(widget.pagina)),
              data: (notas) {
                if (notas.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Ainda sem notas nesta página.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                }
                final ordenadas = [...notas]
                  ..sort((a, b) {
                    if (a.resolvida != b.resolvida) {
                      return a.resolvida ? 1 : -1;
                    }
                    return b.created.compareTo(a.created);
                  });
                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: ordenadas.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final n = ordenadas[i];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: podeResolver
                          ? Checkbox(
                              value: n.resolvida,
                              onChanged: (v) => ref
                                  .read(notaPaginaActionsProvider)
                                  .marcarResolvida(
                                    widget.pagina,
                                    n.id,
                                    v ?? false,
                                  ),
                            )
                          : Icon(
                              n.resolvida
                                  ? Icons.check_circle_outline
                                  : Icons.radio_button_unchecked,
                              size: 20,
                            ),
                      title: Text(
                        n.texto,
                        style: n.resolvida
                            ? const TextStyle(
                                decoration: TextDecoration.lineThrough,
                              )
                            : null,
                      ),
                      subtitle: Text(
                        [
                          if (n.autorNome.isNotEmpty) n.autorNome,
                          if (n.created.isNotEmpty) _dataCurta(n.created),
                          if (n.resolvida && n.resolvidaPor.isNotEmpty)
                            'resolvida por ${n.resolvidaPor}',
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      trailing: podeApagar
                          ? IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              tooltip: 'Apagar',
                              onPressed: () => _apagar(n),
                            )
                          : null,
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Escrever uma nota…',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _adicionar(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _enviando ? null : _adicionar,
                icon: _enviando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
