import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/async_value_view.dart';
import '../../cookie_formats/application/cookie_format_providers.dart';
import '../../recipes/domain/recipe.dart';
import '../../recipes/presentation/recipe_picker_sheet.dart';
import '../../tech_sheets/application/tech_sheets_providers.dart';
import '../../tech_sheets/domain/tech_sheet.dart';

/// O que se pode produzir: um produto final (ficha técnica) ou uma receita
/// (massa, recheio, base…).
sealed class ProdutoEscolhido {
  const ProdutoEscolhido();
}

class ProdutoFicha extends ProdutoEscolhido {
  const ProdutoFicha(this.ficha);
  final FichaTecnica ficha;
}

class ProdutoReceita extends ProdutoEscolhido {
  const ProdutoReceita(this.receita);
  final Receita receita;
}

class _QuerReceitas {
  const _QuerReceitas();
}

/// Folha para escolher o que produzir: primeiro os produtos finais das fichas
/// técnicas (Boston, Provença…), com atalho para escolher antes uma receita.
Future<ProdutoEscolhido?> showProdutoPickerSheet(BuildContext context) async {
  final r = await showModalBottomSheet<Object>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _ProdutoPicker(),
  );
  if (r is FichaTecnica) return ProdutoFicha(r);
  if (r is _QuerReceitas && context.mounted) {
    final rec = await showRecipePickerSheet(context, soFabricoProprio: false);
    return rec == null ? null : ProdutoReceita(rec);
  }
  return null;
}

class _ProdutoPicker extends ConsumerStatefulWidget {
  const _ProdutoPicker();

  @override
  ConsumerState<_ProdutoPicker> createState() => _ProdutoPickerState();
}

class _ProdutoPickerState extends ConsumerState<_ProdutoPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    // a revenda (bebidas…) não se produz
    final async = ref
        .watch(fichasListProvider(false))
        .whenData(
          (l) => [
            for (final f in l)
              if (!f.revenda) f,
          ],
        );
    final formatos = ref.watch(formatosProvider).valueOrNull ?? const [];
    String formatoNome(String id) {
      for (final f in formatos) {
        if (f.id == id) return f.nome;
      }
      return '';
    }

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Text(
              'O que vais produzir?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Procurar produto final',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: AsyncValueView<List<FichaTecnica>>(
                value: async,
                data: (all) {
                  final items = all
                      .where(
                        (f) =>
                            _q.isEmpty ||
                            f.nome.toLowerCase().contains(_q.toLowerCase()),
                      )
                      .toList();
                  return ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 4),
                        child: Text(
                          'Produtos finais',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      if (items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Nenhum produto final encontrado.'),
                        ),
                      for (final f in items)
                        ListTile(
                          key: ValueKey('produto-${f.id}'),
                          leading: const Icon(Icons.cookie_outlined),
                          title: Text(f.nome),
                          subtitle: Text(
                            [
                              if (f.categoria.isNotEmpty) f.categoria,
                              if (formatoNome(f.formatoId).isNotEmpty)
                                formatoNome(f.formatoId),
                            ].join(' · '),
                          ),
                          onTap: () => Navigator.pop(context, f),
                        ),
                      const Divider(),
                      ListTile(
                        key: const ValueKey('produto-receitas'),
                        leading: const Icon(Icons.menu_book_outlined),
                        title: const Text('Receitas'),
                        subtitle: const Text(
                          'Massas, recheios, coberturas e outras bases',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () =>
                            Navigator.pop(context, const _QuerReceitas()),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
