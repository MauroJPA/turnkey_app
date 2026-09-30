import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pocketbase/pb_client.dart';
import '../../import_csv/domain/import_result.dart';
import '../../ingredients/data/ingredient_repository.dart';
import '../../ingredients/domain/ingredient.dart';
import '../../invoices/domain/match_ingrediente.dart';
import '../data/recipe_item_repository.dart';
import '../data/recipe_repository.dart';
import '../domain/receita_csv.dart';
import '../domain/receita_lida_ia.dart';
import '../domain/recipe.dart';
import 'recipes_providers.dart';

final receitasImportServiceProvider = Provider<ReceitasImportService>((ref) {
  return ReceitasImportService(ref);
});

/// Importa receitas de um CSV/texto colado (`nome, categoria, ingrediente,
/// quantidade_g`, várias receitas de uma vez), de uma receita só (nome +
/// lista simples "ingrediente, quantidade_g"), ou lê uma imagem por IA
/// (print/foto de uma lista) para pré-preencher o formulário.
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

  String _mimeImagem(String nome) {
    final n = nome.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  /// Lê uma imagem (print da folha de cálculo, foto de um caderno…) por IA —
  /// SEM gravar nada: o resultado só pré-preenche o formulário, a pessoa
  /// revê/corrige e confirma com "Importar" como sempre.
  Future<ReceitaLidaIa> lerImagem({
    required List<int> bytes,
    required String nome,
  }) async {
    final res = await _ref
        .read(pbProvider)
        .send(
          '/api/gc_turnkey/receitas/ler-imagem',
          method: 'POST',
          body: {'imagem': base64Encode(bytes), 'mime': _mimeImagem(nome)},
        );
    return ReceitaLidaIa.fromJson(Map<String, dynamic>.from(res as Map));
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

  /// Cria a receita de [g] e as suas linhas (ligadas ou pendentes); devolve
  /// `1` se criou, `0` se ignorou (nome já existe) ou falhou (erro anotado
  /// em [erros]). [existentes] é atualizado com o nome criado.
  Future<int> _criarGrupo(
    ReceitaCsvGrupo g,
    RecipeRepository recipeRepo,
    RecipeItemRepository itemRepo,
    List<Ingrediente> ingredientes,
    Set<String> existentes,
    List<String> erros,
  ) async {
    if (existentes.contains(normalizarNome(g.nome))) {
      erros.add(
        '«${g.nome}»: já existe uma receita com este nome — ignorada.',
      );
      return 0;
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
          await itemRepo.addPendente(receita.id, l.ingrediente, l.quantidadeG);
          erros.add(
            '«${g.nome}»: «${l.ingrediente}» sem ingrediente correspondente — '
            'ficou pendente para ligares.',
          );
        }
      }
      return 1;
    } on Object catch (e) {
      erros.add('«${g.nome}»: $e');
      return 0;
    }
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
    final ingredientes = await _ref.read(ingredientRepositoryProvider).list();

    for (final g in parsed.receitas) {
      criadas += await _criarGrupo(
        g,
        recipeRepo,
        itemRepo,
        ingredientes,
        existentes,
        erros,
      );
    }

    _ref.invalidate(recipesListProvider);
    return ImportResult(criados: criadas, erros: erros);
  }

  /// Importa uma única receita: [nome] + [categoria] escolhidos à parte, e
  /// [textoIngredientes] no formato simples "ingrediente, quantidade_g" (uma
  /// linha por ingrediente, sem nome/categoria repetidos em cada linha).
  Future<ImportResult> importarUma({
    required String nome,
    required String categoria,
    required String textoIngredientes,
  }) async {
    final nomeLimpo = nome.trim();
    final erros = <String>[];
    if (nomeLimpo.isEmpty) {
      return ImportResult(criados: 0, erros: ['Escreve o nome da receita.']);
    }
    if (categoria.trim().isEmpty) {
      return ImportResult(criados: 0, erros: ['Escolhe uma categoria.']);
    }

    final parsed = parseIngredientesSimples(textoIngredientes);
    erros.addAll(parsed.erros);
    if (parsed.linhas.isEmpty) {
      erros.add('Sem nenhum ingrediente válido para importar.');
      return ImportResult(criados: 0, erros: erros);
    }

    final recipeRepo = _ref.read(recipeRepositoryProvider);
    final itemRepo = _ref.read(recipeItemRepositoryProvider);
    final existentes = (await recipeRepo.list())
        .map((r) => normalizarNome(r.nome))
        .toSet();
    final ingredientes = await _ref.read(ingredientRepositoryProvider).list();

    final g = ReceitaCsvGrupo(nome: nomeLimpo, categoria: categoria)
      ..linhas.addAll(parsed.linhas);
    final criadas = await _criarGrupo(
      g,
      recipeRepo,
      itemRepo,
      ingredientes,
      existentes,
      erros,
    );

    _ref.invalidate(recipesListProvider);
    return ImportResult(criados: criadas, erros: erros);
  }
}
