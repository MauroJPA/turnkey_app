import 'package:flutter/material.dart';

import '../../ingredients/domain/ingredient.dart';
import '../domain/recipe.dart';

/// Resolve um item que está "sem dados" numa declaração nutricional e abre a
/// folha de nutrição certa — descendo em cascata:
///
/// - id (ou nome) de uma **receita** / massa  -> [abrirReceita] (que por sua
///   vez lista os *seus* ingredientes em falta);
/// - **ingrediente-espelho** (fabrico próprio ligado a uma receita) -> a
///   receita com o mesmo nome, via [abrirReceita];
/// - **ingrediente** normal -> [abrirIngrediente].
///
/// [ings] e [recs] são as listas já carregadas (o chamador observa-as com
/// `ref.watch`, por isso aqui não há `await` a providers). Devolve `true` se
/// abriu alguma folha.
Future<bool> corrigirNutriEmCascata(
  BuildContext context, {
  required List<Ingrediente> ings,
  required List<Receita> recs,
  required ({String id, String nome}) alvo,
  required Future<void> Function(Ingrediente) abrirIngrediente,
  required Future<void> Function(Receita) abrirReceita,
}) async {
  String norm(String s) => s.trim().toLowerCase();

  Receita? rec = recs.where((r) => r.id == alvo.id).firstOrNull;
  final ing = ings.where((i) => i.id == alvo.id).firstOrNull;

  // ingrediente-espelho -> a receita com o mesmo nome
  if (rec == null &&
      ing != null &&
      ing.origem == OrigemIngrediente.fabricoProprio) {
    rec = recs.where((r) => norm(r.nome) == norm(ing.nome)).firstOrNull;
  }

  // cache antiga só com o nome
  Ingrediente? ingPorNome;
  if (rec == null && ing == null) {
    rec = recs.where((r) => norm(r.nome) == norm(alvo.nome)).firstOrNull;
    ingPorNome = rec == null
        ? ings.where((i) => norm(i.nome) == norm(alvo.nome)).firstOrNull
        : null;
  }

  if (rec != null) {
    await abrirReceita(rec);
    return true;
  }
  final alvoIng = ing ?? ingPorNome;
  if (alvoIng != null) {
    await abrirIngrediente(alvoIng);
    return true;
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Não encontrei "${alvo.nome}".')),
    );
  }
  return false;
}
