import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ingredients/application/ingredients_providers.dart';
import '../../ingredients/domain/ingredient.dart';
import '../../ingredients/presentation/nutricao_sheet.dart';
import '../application/recipes_providers.dart';
import 'nutricao_receita_sheet.dart';

/// Abre a folha de nutrição certa para um item que está "sem dados" numa
/// declaração nutricional — descendo em cascata:
///
/// - id (ou nome) de uma **receita** / massa  -> folha de nutrição da receita
///   (que por sua vez lista os *seus* ingredientes em falta);
/// - **ingrediente-espelho** (fabrico próprio ligado a uma receita) -> a folha
///   dessa receita;
/// - **ingrediente** normal -> folha de nutrição e alergénios do ingrediente.
///
/// Devolve `true` se abriu alguma folha (o chamador deve então invalidar os
/// seus providers).
Future<bool> corrigirNutriEmCascata(
  BuildContext context,
  WidgetRef ref, {
  required ({String id, String nome}) alvo,
}) async {
  final ings = await ref.read(ingredientsListProvider(false).future);
  final recs = await ref.read(recipesListProvider(false).future);
  if (!context.mounted) return false;

  String norm(String s) => s.trim().toLowerCase();

  // 1) o id é de uma receita?
  var rec = recs.where((r) => r.id == alvo.id).firstOrNull;

  // 2) o id é de um ingrediente?
  final ing = ings.where((i) => i.id == alvo.id).firstOrNull;

  // 2a) ingrediente-espelho -> a receita com o mesmo nome
  if (rec == null &&
      ing != null &&
      ing.origem == OrigemIngrediente.fabricoProprio) {
    rec = recs.where((r) => norm(r.nome) == norm(ing.nome)).firstOrNull;
  }

  // 3) sem id útil (cache antiga só com o nome) -> tenta pelo nome
  if (rec == null && ing == null) {
    rec = recs.where((r) => norm(r.nome) == norm(alvo.nome)).firstOrNull;
  }
  final ingPorNome = (rec == null && ing == null)
      ? ings.where((i) => norm(i.nome) == norm(alvo.nome)).firstOrNull
      : null;

  if (rec != null) {
    await showNutricaoReceitaSheet(context, receita: rec);
    return true;
  }
  final alvoIng = ing ?? ingPorNome;
  if (alvoIng != null) {
    await showNutricaoSheet(context, ingrediente: alvoIng);
    return true;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Não encontrei "${alvo.nome}".')),
  );
  return false;
}
