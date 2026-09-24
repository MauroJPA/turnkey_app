import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/help/help_content.dart';
import '../../../core/nutrition/nutri_widgets.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/help_actions.dart';
import '../../cookie_formats/application/cookie_format_providers.dart';
import '../../tech_sheets/application/tech_sheets_providers.dart';
import '../../tech_sheets/domain/tech_sheet.dart';
import '../domain/produto_gookie.dart';

/// Tudo o que a Gookie produz (os produtos finais das fichas técnicas), com o
/// estado da informação nutricional de cada um.
class ProdutosGookieScreen extends ConsumerStatefulWidget {
  const ProdutosGookieScreen({super.key});

  @override
  ConsumerState<ProdutosGookieScreen> createState() =>
      _ProdutosGookieScreenState();
}

class _ProdutosGookieScreenState extends ConsumerState<ProdutosGookieScreen> {
  String _q = '';
  bool _soPorCompletar = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(fichasListProvider(false));
    final formatos = ref.watch(formatosProvider).valueOrNull ?? const [];
    String formatoNome(String id) {
      for (final f in formatos) {
        if (f.id == id) return f.nome;
      }
      return '';
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
        title: const Text('Produtos Gookie'),
        actions: const [HelpActions(topic: HelpTopic.produtosGookie)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Procurar produto',
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                label: const Text('Só os que faltam completar'),
                selected: _soPorCompletar,
                onSelected: (v) => setState(() => _soPorCompletar = v),
              ),
            ),
          ),
          Expanded(
            child: AsyncValueView<List<FichaTecnica>>(
              value: async,
              onRetry: () => ref.invalidate(fichasListProvider(false)),
              data: (todas) {
                final itens = todas.where((f) {
                  final q = _q.trim().toLowerCase();
                  if (q.isNotEmpty && !f.nome.toLowerCase().contains(q)) {
                    return false;
                  }
                  if (_soPorCompletar && pendenciasProduto(f).isEmpty) {
                    return false;
                  }
                  return true;
                }).toList();
                if (itens.isEmpty) {
                  return Center(
                    child: Text(
                      todas.isEmpty
                          ? 'Ainda sem produtos. Cria uma ficha técnica.'
                          : 'Nada corresponde ao filtro.',
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: itens.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) =>
                      _tile(itens[i], formatoNome(itens[i].formatoId)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(FichaTecnica f, String formato) {
    final cs = Theme.of(context).colorScheme;
    final pend = pendenciasProduto(f);
    final n = f.nutri;
    final completa = nutricaoCompleta(f);
    final alerg = alergeniosResumo(n.alergenios, n.alergeniosTracos);
    return ListTile(
      key: ValueKey('produto-${f.id}'),
      leading: Icon(
        completa ? Icons.verified_outlined : Icons.warning_amber_rounded,
        color: completa ? cs.primary : cs.error,
      ),
      title: Text(f.nome),
      subtitle: Text(
        [
          if (f.categoria.isNotEmpty) f.categoria,
          if (formato.isNotEmpty) formato,
          if (n.pesoUnidadeG > 0) '${n.pesoUnidadeG.toStringAsFixed(0)} g',
          if (f.validadeDias > 0) 'validade ${f.validadeDias} d',
          if (alerg.isNotEmpty) alerg,
          if (pend.isNotEmpty) 'Falta: ${pend.join(' · ')}',
        ].join(' · '),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.go('${Routes.produtosGookie}/${f.id}'),
    );
  }
}
