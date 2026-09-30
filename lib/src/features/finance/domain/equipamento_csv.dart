import 'package:csv/csv.dart';

import 'equipamento.dart';

/// Resultado da leitura de um CSV de equipamentos.
class EquipamentoCsvParseResult {
  EquipamentoCsvParseResult({List<EquipamentoInput>? itens, List<String>? erros})
      : itens = itens ?? [],
        erros = erros ?? [];

  final List<EquipamentoInput> itens;
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

/// Tab (colar da folha de cálculo), depois `;`, depois `,`.
String _delimitador(String primeiraLinha) {
  if (primeiraLinha.contains('\t')) return '\t';
  if (primeiraLinha.contains(';')) return ';';
  return ',';
}

/// Lê um CSV (ou texto colado) de equipamentos — colunas
/// `nome, custo, vida_util_anos, notas` (a última é opcional). `€` e vírgula
/// decimal tolerados; delimitador tab/`;`/`,` detetado automaticamente;
/// cabeçalho opcional, detetado se a 1ª célula for "nome"/"equipamento"/"custo".
EquipamentoCsvParseResult parseEquipamentosCsv(String content) {
  final normalized = content
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .trim();
  if (normalized.isEmpty) return EquipamentoCsvParseResult();

  final primeiraLinha = normalized.split('\n').first;
  final rows = CsvToListConverter(
    fieldDelimiter: _delimitador(primeiraLinha),
    eol: '\n',
    shouldParseNumbers: false,
    allowInvalid: true,
  ).convert(normalized);

  final itens = <EquipamentoInput>[];
  final erros = <String>[];

  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    if (row.every((c) => _clean(c).isEmpty)) continue;
    if (row.length < 3) continue;
    final primeira = _clean(row[0]).toLowerCase();
    if (i == 0 &&
        (primeira == 'nome' ||
            primeira == 'equipamento' ||
            primeira == 'custo')) {
      continue; // cabeçalho
    }

    final nome = _clean(row[0]);
    final custo = _parseNum(row[1]);
    final vidaUtil = _parseNum(row[2]);
    final notas = row.length > 3 ? _clean(row[3]) : '';

    if (nome.isEmpty ||
        custo == null ||
        custo <= 0 ||
        vidaUtil == null ||
        vidaUtil <= 0) {
      erros.add('Linha ${i + 1}: dados inválidos ("${row.join(', ')}").');
      continue;
    }

    itens.add(
      EquipamentoInput(
        nome: nome,
        custo: custo,
        vidaUtilAnos: vidaUtil,
        notas: notas,
      ),
    );
  }

  return EquipamentoCsvParseResult(itens: itens, erros: erros);
}
