import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../recipes/data/recipe_item_repository.dart';
import '../../recipes/data/recipe_repository.dart';
import '../domain/production.dart';

typedef ProductionArgs = ({String recipeId, double alvoG});

/// Constrói a árvore de produção de uma receita para [alvoG] gramas,
/// escalando cada ingrediente pela sua percentagem na mistura para que a
/// soma das quantidades seja exatamente [alvoG]. Expande sub-receitas
/// recursivamente.
final productionProvider =
    FutureProvider.autoDispose.family<ProductionNode, ProductionArgs>(
  (ref, args) async {
    final recipes = ref.watch(recipeRepositoryProvider);
    final items = ref.watch(recipeItemRepositoryProvider);

    Future<ProductionNode> build(
      String id,
      double alvoG,
      Set<String> caminho,
    ) async {
      final receita = await recipes.getById(id);

      if (caminho.contains(id)) {
        return ProductionNode(
          receitaId: id,
          nome: receita.nome,
          alvoG: alvoG,
          rendimentoBase: 0,
          linhas: const [],
          subReceitas: const [],
          ciclo: true,
        );
      }
      final proximoCaminho = {...caminho, id};

      final linhasReceita = await items.listForRecipe(id);
      // Base = soma das quantidades das linhas; escalar para que o total
      // produzido seja [alvoG] (proporção de cada ingrediente mantida).
      final pesoBase =
          linhasReceita.fold<double>(0, (s, it) => s + it.quantidadeG);
      final fator = pesoBase > 0 ? alvoG / pesoBase : 0.0;

      final linhas = <ProductionLine>[];
      final subs = <ProductionNode>[];

      for (final it in linhasReceita) {
        final qtd = it.quantidadeG * fator;
        if (it.subReceitaId != null) {
          subs.add(await build(it.subReceitaId!, qtd, proximoCaminho));
        } else if (it.eEspelho) {
          // ingrediente que é uma receita própria -> explode também
          subs.add(await build(it.ingredienteEspelhoId!, qtd, proximoCaminho));
        } else {
          linhas.add(
            ProductionLine(
              nome: it.nome,
              quantidadeG: qtd,
              custo: it.custoPorGramaResolvido * qtd,
              pendente: it.pendente,
            ),
          );
        }
      }

      return ProductionNode(
        receitaId: id,
        nome: receita.nome,
        alvoG: alvoG,
        rendimentoBase: pesoBase,
        linhas: linhas,
        subReceitas: subs,
      );
    }

    return build(args.recipeId, args.alvoG, <String>{});
  },
);
