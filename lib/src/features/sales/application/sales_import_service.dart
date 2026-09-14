import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../import_csv/domain/import_result.dart';
import '../../tech_sheets/application/tech_sheets_providers.dart';
import '../domain/venda.dart';
import '../domain/venda_csv.dart';
import 'sales_providers.dart';

final salesImportServiceProvider = Provider<SalesImportService>((ref) {
  return SalesImportService(ref);
});

/// Resultado de uma importação de CSV de vendas. `criados` (herdado) é o
/// número de dias/vendas criadas.
class VendaImportResult extends ImportResult {
  VendaImportResult({
    required int dias,
    required this.linhas,
    required this.naoIdentificados,
    super.erros,
  }) : super(criados: dias);

  final int linhas;
  final int naoIdentificados;

  @override
  String get resumo {
    final partes = <String>['$criados dia(s), $linhas linha(s)'];
    if (naoIdentificados > 0) {
      partes.add('$naoIdentificados sem produto identificado');
    }
    return partes.join(' — ');
  }
}

/// Importa vendas de um CSV (`data,produto,quantidade,preco_unitario`),
/// associando cada linha à ficha técnica mais parecida (por nome).
class SalesImportService {
  SalesImportService(this._ref);
  final Ref _ref;

  Future<VendaImportResult> pickAndImport() async {
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

  Future<VendaImportResult> importCsv(String content) async {
    final fichas = await _ref.read(fichasListProvider(false).future);
    final parsed = parseVendasCsv(content, fichas);

    final erros = [...parsed.erros];
    var dias = 0;
    for (final grupo in parsed.grupos) {
      try {
        await _ref.read(salesActionsProvider).criar(
              data: grupo.data,
              origem: OrigemVenda.csv,
              linhas: grupo.itens,
            );
        dias++;
      } on Object catch (e) {
        erros.add('${ymd(grupo.data)}: $e');
      }
    }

    return VendaImportResult(
      dias: dias,
      linhas: parsed.totalLinhas,
      naoIdentificados: parsed.totalNaoIdentificados,
      erros: erros,
    );
  }
}
