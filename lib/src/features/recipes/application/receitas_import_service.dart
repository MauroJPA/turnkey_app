import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../import_csv/domain/import_result.dart';
import '../../ingredients/data/ingredient_repository.dart';
import '../../ingredients/domain/ingredient.dart';
import '../../invoices/domain/match_ingrediente.dart';
import '../data/recipe_item_repository.dart';
import '../data/recipe_repository.dart';
import '../domain/receita_csv.dart';
import '../domain/recipe.dart';
import 'recipes_providers.dart';

final receitasImportServiceProvider = Provider<ReceitasImportService>((ref) {
  return ReceitasImportService(ref);
});

/// Importa receitas de um CSV (ou texto colado): `nome, categoria,
/// ingrediente, quantidade_g`, uma linha por ingrediente.
class ReceitasImportService {
  ReceitasImportService(this._ref);
  final Ref _ref;

  Future<String> pickCsv() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt', 'tsv'],
      withData: true,
    );
    final bytes = picked?.files.single.bytes;
    if (bytes == null) throw const ImportCancelled();
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }

  /// Ingrediente com o mesmo nome (sem acentos/maiúsculas) ou, senão, o mais
  /// parecido; `null` se nada bate (a linha fica pendente).
  Ingrediente? _corresponder(String nome, List<Ingrediente> todos) {
    final alvo = normalizarNome(nome);
    for (final i in todos) {
      if (normalizarNome(i.nome) == alvo) return i;
    }
    return melhorMatch(nome, todos);
  }

  Future<ImportResult> importCsv(String content) async {
    final parsed = parseReceitasCsv(content);
    final erros = [...parsed.erros];
    var criadas = 0;

    final recipeRepo = _ref.read(recipeRepositoryProvider);
    final itemRepo = _ref.read(recipeItemRepositoryProvider);
    final existentes = (await recipeRepo.list())
        .map((r) => normalizarNome(r.nome))
        .toSet();
    final ingredientes =
        await _ref.read(ingredientRepositoryProvider).list();

    for (final g in parsed.receitas) {
      if (existentes.contains(normalizarNome(g.nome))) {
        erros.add('«${g.nome}»: já existe uma receita com este nome — ignorada.');
        continue;
      }
      try {
        final receita = await recipeRepo.create(
          RecipeInput(nome: g.nome, categoria: g.categoria),
        );
        existentes.add(normalizarNome(g.nome));
        for (final l in g.linhas) {
          final ing = _corresponder(l.ingrediente, ingredientes);
          if (ing != null) {
            await itemRepo.addIngrediente(receita.id, ing.id, l.quantidadeG);
          } else {
            await itemRepo.addPendente(
              receita.id,
              l.ingrediente,
              l.quantidadeG,
            );
            erros.add(
              '«${g.nome}»: «${l.ingrediente}» sem ingrediente correspondente — '
              'ficou pendente para ligares.',
            );
          }
        }
        criadas++;
      } on Object catch (e) {
        erros.add('«${g.nome}»: $e');
      }
    }

    _ref.invalidate(recipesListProvider);
    return ImportResult(criados: criadas, erros: erros);
  }
}
