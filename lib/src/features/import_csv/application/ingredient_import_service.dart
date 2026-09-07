import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ingredients/data/ingredient_repository.dart';
import '../../ingredients/domain/ingredient.dart';
import '../domain/import_result.dart';

final ingredientImportServiceProvider = Provider<IngredientImportService>((ref) {
  return IngredientImportService(ref.watch(ingredientRepositoryProvider));
});

/// Importa ingredientes de um CSV.
///
/// Formato (como no `meu_app_ia`): separado por vírgula, colunas
/// `nome, caracteristica, marca, fornecedor, preco, gramas`.
/// Uma linha de cabeçalho é ignorada se a 1ª célula for "nome" ou contiver
/// "ingrediente". `€` e vírgula decimal no preço são tolerados.
class IngredientImportService {
  IngredientImportService(this._repo);

  final IngredientWriter _repo;

  Future<ImportResult> pickAndImport() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    final bytes = picked?.files.single.bytes;
    if (bytes == null) throw const ImportCancelled();

    return importCsv(_decode(bytes));
  }

  String _decode(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }

  Future<ImportResult> importCsv(String content) async {
    final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rows = const CsvToListConverter(
      fieldDelimiter: ',',
      eol: '\n',
      shouldParseNumbers: false,
      allowInvalid: true,
    ).convert(normalized.trim());

    final result = ImportResult();

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 6) continue;

      final nome = _clean(row[0]);
      if (nome.isEmpty) continue;
      final first = nome.toLowerCase();
      if (i == 0 && (first == 'nome' || first.contains('ingrediente'))) {
        continue; // cabeçalho
      }

      final preco = _parseNum(row[4]);
      final gramas = _parseNum(row[5]);
      if (preco == null || gramas == null) {
        result.erros.add('Linha ${i + 1} ("$nome"): preço ou gramas inválidos.');
        continue;
      }

      final input = IngredienteInput(
        nome: nome,
        caracteristica: _clean(row[1]),
        marca: _clean(row[2]),
        fornecedor: _clean(row[3]),
        preco: preco,
        gramasEmbalagem: gramas,
      );

      try {
        final existente = await _repo.findByName(nome);
        if (existente == null) {
          await _repo.create(input);
          result.criados++;
        } else {
          await _repo.update(existente.id, input);
          result.atualizados++;
        }
      } on Object catch (e) {
        result.erros.add('Linha ${i + 1} ("$nome"): $e');
      }
    }

    return result;
  }

  String _clean(Object? v) => v.toString().replaceAll('"', '').trim();

  double? _parseNum(Object? v) {
    final s = v
        .toString()
        .replaceAll('€', '')
        .replaceAll('"', '')
        .replaceAll(',', '.')
        .trim();
    return s.isEmpty ? null : double.tryParse(s);
  }
}
