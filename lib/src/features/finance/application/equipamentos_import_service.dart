import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../import_csv/domain/import_result.dart';
import '../domain/equipamento_csv.dart';
import 'equipamentos_providers.dart';

final equipamentosImportServiceProvider =
    Provider<EquipamentosImportService>((ref) {
  return EquipamentosImportService(ref);
});

/// Importa equipamentos de um CSV (`nome, custo, vida_util_anos`).
class EquipamentosImportService {
  EquipamentosImportService(this._ref);
  final Ref _ref;

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
    final parsed = parseEquipamentosCsv(content);
    final erros = [...parsed.erros];
    var criados = 0;
    for (final item in parsed.itens) {
      try {
        await _ref.read(equipamentosActionsProvider).create(item);
        criados++;
      } on Object catch (e) {
        erros.add('${item.nome}: $e');
      }
    }
    return ImportResult(criados: criados, erros: erros);
  }
}
