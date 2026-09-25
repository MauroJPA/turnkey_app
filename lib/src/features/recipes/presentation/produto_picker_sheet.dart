import 'package:flutter/material.dart';

import '../../ingredients/domain/ingredient.dart';
import '../../ingredients/domain/produto_ingrediente.dart';

/// Resultado do seletor: [id] `null` = "automático" (custo do genérico).
class EscolhaProduto {
  const EscolhaProduto(this.id);
  final String? id;
}

String _euro(double v) => '${v.toStringAsFixed(2).replaceAll('.', ',')} €';

String _data(DateTime? d) => d == null
    ? 'sem data'
    : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Escolhe o produto de compra de um ingrediente genérico para uma linha de
/// receita. "Automático" usa sempre a compra mais recente.
Future<EscolhaProduto?> showProdutoPicker(
  BuildContext context, {
  required Ingrediente ingrediente,
  required List<ProdutoIngrediente> produtos,
  String? atualId,
}) => showModalBottomSheet<EscolhaProduto>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _ProdutoPicker(
    ingrediente: ingrediente,
    produtos: produtos,
    atualId: atualId,
  ),
);

class _ProdutoPicker extends StatelessWidget {
  const _ProdutoPicker({
    required this.ingrediente,
    required this.produtos,
    required this.atualId,
  });

  final Ingrediente ingrediente;
  final List<ProdutoIngrediente> produtos;
  final String? atualId;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final recente = produtoMaisRecente(produtos);
    final ordenados = [...produtos]
      ..sort((a, b) {
        final da = a.precoAtualizadoEm ?? DateTime(0);
        final db = b.precoAtualizadoEm ?? DateTime(0);
        return db.compareTo(da);
      });

    Widget opcao({
      required bool escolhido,
      required String titulo,
      required String subtitulo,
      required String? id,
      Widget? extra,
    }) => ListTile(
      leading: Icon(
        escolhido ? Icons.radio_button_checked : Icons.radio_button_off,
        color: escolhido ? cs.primary : null,
      ),
      title: Text(titulo),
      subtitle: Text(subtitulo),
      trailing: extra,
      onTap: () => Navigator.pop(context, EscolhaProduto(id)),
    );

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Produto de ${ingrediente.nome}',
                style: tt.titleMedium,
              ),
            ),
            opcao(
              escolhido: atualId == null,
              titulo: 'Automático',
              subtitulo: recente == null
                  ? 'Usa o custo do ingrediente'
                  : 'Usa sempre a compra mais recente (agora: ${recente.resumo}). '
                        'Os alergénios e a nutrição são os do ingrediente.',
              id: null,
            ),
            const Divider(height: 1),
            for (final p in ordenados)
              opcao(
                escolhido: atualId == p.id,
                titulo: p.marca.isNotEmpty ? '${p.marca} · ${p.nome}' : p.nome,
                subtitulo: [
                  p.resumo,
                  if (p.temPreco)
                    '${_euro(p.preco / p.embalagemG * 1000)}/kg'
                  else
                    'sem preço',
                  _data(p.precoAtualizadoEm),
                  if (p.fornecedor.isNotEmpty) p.fornecedor,
                  if (p.alergenios.isNotEmpty)
                    'contém também: ${p.alergenios.join(', ')}',
                  if (p.alergeniosTracos.isNotEmpty)
                    'pode conter: ${p.alergeniosTracos.join(', ')}',
                  if (p.nutriPropria) 'nutrição própria',
                ].join(' · '),
                id: p.id,
                extra: p.id == recente?.id
                    ? Chip(
                        label: const Text('mais recente'),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: cs.primaryContainer,
                      )
                    : null,
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
