import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/mensagem_amigavel.dart';
import '../../ingredients/application/ingredients_providers.dart';
import '../../ingredients/domain/ingredient.dart';
import '../application/recipes_providers.dart';
import '../domain/auto_link_pendentes.dart';
import 'item_picker_sheet.dart';

/// Tenta ligar automaticamente, pelo nome, todos os itens "por ligar" da
/// receita [recipeId]: nomes exatamente iguais a um ingrediente ligam-se
/// logo; os restantes (sem nome exato) ficam num sheet de revisão, com a
/// melhor sugestão pré-preenchida, para confirmar/trocar/ignorar cada um.
Future<void> ligarPendentesAutomaticamente(
  BuildContext context,
  WidgetRef ref,
  String recipeId,
) async {
  final RecipeDetail detail;
  final List<Ingrediente> ingredientes;
  try {
    detail = await ref.read(recipeDetailProvider(recipeId).future);
    ingredientes = await ref.read(ingredientsListProvider(false).future);
  } on Object catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensagemAmigavel(e))));
    }
    return;
  }

  final pendentes = detail.itens.where((i) => i.pendente).toList();
  if (pendentes.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não há linhas por ligar nesta receita.')),
      );
    }
    return;
  }

  final sugestoes = sugerirLigacoes(pendentes, ingredientes);
  final exatos = sugestoes.where((s) => s.temExato).toList();
  final restantes = sugestoes.where((s) => !s.temExato).toList();

  final actions = ref.read(recipeActionsProvider);
  var ligados = 0;

  if (exatos.isNotEmpty) {
    try {
      await actions.vincularVarios(recipeId, [
        for (final s in exatos)
          (itemId: s.item.id, ingredienteId: s.exato!.id, subReceitaId: null),
      ]);
      ligados += exatos.length;
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao ligar automaticamente: ${mensagemAmigavel(e)}')),
        );
      }
    }
  }

  if (restantes.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$ligados linha(s) ligada(s) automaticamente pelo nome.'),
        ),
      );
    }
    return;
  }

  if (!context.mounted) return;
  final revisao = await showModalBottomSheet<
      List<({String itemId, String? ingredienteId, String? subReceitaId})>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _RevisaoLigacoesSheet(sugestoes: restantes),
  );

  if (revisao != null && revisao.isNotEmpty) {
    try {
      await actions.vincularVarios(recipeId, revisao);
      ligados += revisao.length;
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao ligar: ${mensagemAmigavel(e)}')));
      }
    }
  }

  final porRever = restantes.length - (revisao?.length ?? 0);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ligados == 0
              ? 'Nenhuma linha ligada.'
              : '$ligados linha(s) ligada(s)'
                    '${porRever > 0 ? ' · $porRever por rever manualmente' : ''}.',
        ),
      ),
    );
  }
}

class _RevisaoLigacoesSheet extends StatefulWidget {
  const _RevisaoLigacoesSheet({required this.sugestoes});
  final List<SugestaoLigacao> sugestoes;

  @override
  State<_RevisaoLigacoesSheet> createState() => _RevisaoLigacoesSheetState();
}

class _RevisaoLigacoesSheetState extends State<_RevisaoLigacoesSheet> {
  final Map<String, PickedItem?> _escolhido = {};
  final Set<String> _incluidos = {};

  @override
  void initState() {
    super.initState();
    for (final s in widget.sugestoes) {
      final sug = s.sugestao;
      if (sug != null) {
        _escolhido[s.item.id] = PickedItem(
          kind: PickedKind.ingrediente,
          id: sug.id,
          nome: sug.nomeComCaracteristica,
          quantidadeG: 0,
        );
        _incluidos.add(s.item.id);
      }
    }
  }

  Future<void> _escolher(String itemId) async {
    final picked = await showItemPickerSheet(context, apenasVincular: true);
    if (picked == null) return;
    setState(() {
      _escolhido[itemId] = picked;
      _incluidos.add(itemId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Rever ligações (${widget.sugestoes.length})',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            const Text(
              'Sem nome exatamente igual a um ingrediente — confirma a '
              'sugestão, troca por outro, ou desmarca para ignorar.',
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: widget.sugestoes.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final s = widget.sugestoes[i];
                  final escolhido = _escolhido[s.item.id];
                  final incluido = _incluidos.contains(s.item.id);
                  return CheckboxListTile(
                    value: escolhido != null && incluido,
                    onChanged: escolhido == null
                        ? null
                        : (v) => setState(() {
                            if (v ?? false) {
                              _incluidos.add(s.item.id);
                            } else {
                              _incluidos.remove(s.item.id);
                            }
                          }),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(s.item.nomeProvisorio),
                    subtitle: Text(
                      escolhido != null
                          ? 'Vai ligar a "${escolhido.nome}"'
                          : 'Sem sugestão — escolhe manualmente',
                      style: escolhido == null
                          ? TextStyle(color: cs.error)
                          : null,
                    ),
                    secondary: TextButton(
                      onPressed: () => _escolher(s.item.id),
                      child: Text(escolhido == null ? 'Escolher' : 'Trocar'),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _incluidos.isEmpty
                  ? null
                  : () {
                      final resultado = [
                        for (final id in _incluidos)
                          if (_escolhido[id] != null)
                            (
                              itemId: id,
                              ingredienteId:
                                  _escolhido[id]!.kind == PickedKind.ingrediente
                                  ? _escolhido[id]!.id
                                  : null,
                              subReceitaId:
                                  _escolhido[id]!.kind == PickedKind.subReceita
                                  ? _escolhido[id]!.id
                                  : null,
                            ),
                      ];
                      Navigator.pop(context, resultado);
                    },
              child: Text('Ligar selecionados (${_incluidos.length})'),
            ),
          ],
        ),
      ),
    );
  }
}
