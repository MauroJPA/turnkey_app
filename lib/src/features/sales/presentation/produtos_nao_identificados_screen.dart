import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting/money_provider.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../tech_sheets/application/tech_sheets_providers.dart';
import '../../tech_sheets/presentation/ficha_form_sheet.dart';
import '../../tech_sheets/presentation/ficha_picker_sheet.dart';
import '../application/sales_providers.dart';
import '../domain/produto_nao_identificado.dart';

/// Linhas de venda (Vendus/CSV) sem produto identificado, agrupadas por
/// descrição exata — liga cada uma a um produto já existente, ou cria um
/// novo; a ligação aplica-se de uma vez a todas as linhas passadas com essa
/// descrição, e o servidor passa a reconhecê-la sozinho em futuras vendas.
class ProdutosNaoIdentificadosScreen extends ConsumerWidget {
  const ProdutosNaoIdentificadosScreen({super.key});

  Future<void> _ligarExistente(
    BuildContext context,
    WidgetRef ref,
    ProdutoNaoIdentificado p,
  ) async {
    final ficha = await showFichaPickerSheet(context);
    if (ficha == null || !context.mounted) return;
    await _concluirLigacao(context, ref, p, ficha.id, ficha.nome);
  }

  Future<void> _criarNovo(
    BuildContext context,
    WidgetRef ref,
    ProdutoNaoIdentificado p,
  ) async {
    final input = await showFichaFormSheet(context, nomeInicial: p.descricao);
    if (input == null || !context.mounted) return;
    final criada = await ref.read(fichaActionsProvider).create(input);
    if (!context.mounted) return;
    await _concluirLigacao(context, ref, p, criada.id, criada.nome);
  }

  Future<void> _concluirLigacao(
    BuildContext context,
    WidgetRef ref,
    ProdutoNaoIdentificado p,
    String fichaId,
    String fichaNome,
  ) async {
    try {
      final n = await ref
          .read(salesActionsProvider)
          .ligarProduto(descricao: p.descricao, fichaId: fichaId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ligado a "$fichaNome" — $n linha(s) de venda atualizada(s).',
            ),
          ),
        );
      }
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _escolherAcao(
    BuildContext context,
    WidgetRef ref,
    ProdutoNaoIdentificado p,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                p.descricao,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Ligar a um produto já existente'),
              onTap: () {
                Navigator.pop(ctx);
                _ligarExistente(context, ref, p);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_box_outlined),
              title: const Text('Criar produto novo'),
              onTap: () {
                Navigator.pop(ctx);
                _criarNovo(context, ref, p);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(produtosNaoIdentificadosProvider);
    final fmt = ref.watch(moneyFormatProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Produtos não identificados')),
      body: AsyncValueView<List<ProdutoNaoIdentificado>>(
        value: async,
        onRetry: () => ref.invalidate(produtosNaoIdentificadosProvider),
        data: (lista) {
          if (lista.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Nada por identificar — todas as vendas têm produto associado.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'Toca numa descrição para a ligar a um produto — a '
                  'ligação aplica-se a todas as vendas passadas com essa '
                  'descrição, e as próximas são reconhecidas sozinhas.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              for (final p in lista)
                ListTile(
                  leading: const Icon(Icons.link_off, color: Colors.red),
                  title: Text(p.descricao.isEmpty ? '(sem descrição)' : p.descricao),
                  subtitle: Text(
                    '${p.linhas} linha(s) · '
                    '${p.quantidade.toStringAsFixed(p.quantidade == p.quantidade.roundToDouble() ? 0 : 2)} un.',
                  ),
                  trailing: Text(
                    fmt(p.total),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () => _escolherAcao(context, ref, p),
                ),
            ],
          );
        },
      ),
    );
  }
}
