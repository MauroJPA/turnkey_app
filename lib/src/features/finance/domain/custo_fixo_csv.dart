import 'package:csv/csv.dart';

import 'custo_fixo.dart';

/// Resultado da leitura de um CSV de custos fixos.
class CustoFixoCsvParseResult {
  CustoFixoCsvParseResult({List<CustoFixoInput>? itens, List<String>? erros})
      : itens = itens ?? [],
        erros = erros ?? [];

  final List<CustoFixoInput> itens;
  final List<String> erros;

  bool get vazio => itens.isEmpty;
}

double? _parseNum(Object? v) {
  final s = v
      .toString()
      .replaceAll('€', '')
      .replaceAll('"', '')
      .replaceAll(',', '.')
      .trim();
  return s.isEmpty ? null : double.tryParse(s);
}

String _clean(Object? v) => v.toString().replaceAll('"', '').trim();

/// Lê um CSV de custos fixos — colunas `nome, valor_mensal, dia_pagamento`
/// (a 3ª é opcional; `€` e vírgula decimal tolerados; cabeçalho opcional,
/// detetado se a 1ª célula for "nome"/"tipo"/"custo"). Cada linha entra
/// como um custo do tipo "fixo" — o tipo pode ser mudado depois na app.
CustoFixoCsvParseResult parseCustosFixosCsv(String content) {
  final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final rows = const CsvToListConverter(
    fieldDelimiter: ',',
    eol: '\n',
    shouldParseNumbers: false,
    allowInvalid: true,
  ).convert(normalized.trim());

  final itens = <CustoFixoInput>[];
  final erros = <String>[];

  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    if (row.length < 2) continue;
    final primeira = _clean(row[0]).toLowerCase();
    if (i == 0 &&
        (primeira == 'nome' || primeira == 'tipo' || primeira == 'custo')) {
      continue; // cabeçalho
    }

    final nome = _clean(row[0]);
    final valor = _parseNum(row[1]);
    final dia = row.length > 2 ? int.tryParse(_clean(row[2])) : null;

    if (nome.isEmpty || valor == null || valor <= 0) {
      erros.add('Linha ${i + 1}: dados inválidos ("${row.join(', ')}").');
      continue;
    }

    itens.add(
      CustoFixoInput(
        nome: nome,
        tipo: TipoCusto.fixo,
        valorMensal: valor,
        diaPagamento: (dia != null && dia >= 1 && dia <= 31) ? dia : null,
      ),
    );
  }

  return CustoFixoCsvParseResult(itens: itens, erros: erros);
}
