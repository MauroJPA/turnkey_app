import 'package:csv/csv.dart';

import 'recipe.dart';

class ReceitaCsvLinha {
  const ReceitaCsvLinha({required this.ingrediente, required this.quantidadeG});
  final String ingrediente;
  final double quantidadeG;
}

class ReceitaCsvGrupo {
  ReceitaCsvGrupo({required this.nome, required this.categoria});
  final String nome;
  final String categoria;
  final List<ReceitaCsvLinha> linhas = [];
}

class ReceitaCsvParseResult {
  ReceitaCsvParseResult({List<ReceitaCsvGrupo>? receitas, List<String>? erros})
    : receitas = receitas ?? [],
      erros = erros ?? [];

  final List<ReceitaCsvGrupo> receitas;
  final List<String> erros;

  bool get vazio => receitas.isEmpty;
}

double? _parseNum(String v) {
  final s = v.replaceAll(RegExp(r'[gG]\s*$'), '').replaceAll(',', '.').trim();
  return s.isEmpty ? null : double.tryParse(s);
}

String _clean(Object? v) => v.toString().replaceAll('"', '').trim();

/// Tab (colar da folha de cálculo), depois `;`, depois `,`.
String _delimitador(String primeiraLinha) {
  if (primeiraLinha.contains('\t')) return '\t';
  if (primeiraLinha.contains(';')) return ';';
  return ',';
}

/// Lê um CSV (ou texto colado) de receitas — uma linha por ingrediente,
/// colunas `nome, categoria, ingrediente, quantidade_g`. As linhas com o
/// mesmo nome de receita juntam-se numa só receita (categoria da 1.ª linha).
/// Cabeçalho opcional; `g` e vírgula decimal tolerados.
ReceitaCsvParseResult parseReceitasCsv(String content) {
  final normalized = content
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .trim();
  if (normalized.isEmpty) return ReceitaCsvParseResult();

  final primeiraLinha = normalized.split('\n').first;
  final rows = CsvToListConverter(
    fieldDelimiter: _delimitador(primeiraLinha),
    eol: '\n',
    shouldParseNumbers: false,
    allowInvalid: true,
  ).convert(normalized);

  final grupos = <String, ReceitaCsvGrupo>{};
  final erros = <String>[];

  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    if (row.every((c) => _clean(c).isEmpty)) continue;
    if (row.length < 4) {
      erros.add('Linha ${i + 1}: faltam colunas ("${row.join(' | ')}").');
      continue;
    }
    final nome = _clean(row[0]);
    if (i == 0) {
      final p = nome.toLowerCase();
      if (p == 'nome' || p == 'receita') continue; // cabeçalho
    }
    final categoria = _clean(row[1]);
    final ingrediente = _clean(row[2]);
    final qtd = _parseNum(_clean(row[3]));

    if (nome.isEmpty || ingrediente.isEmpty || qtd == null || qtd <= 0) {
      erros.add('Linha ${i + 1}: dados inválidos ("${row.join(' | ')}").');
      continue;
    }

    final chave = nome.toLowerCase();
    final grupo = grupos.putIfAbsent(
      chave,
      () => ReceitaCsvGrupo(
        nome: nome,
        categoria: categoriaReceitaDeTextoLegado(categoria),
      ),
    );
    grupo.linhas.add(
      ReceitaCsvLinha(ingrediente: ingrediente, quantidadeG: qtd),
    );
  }

  return ReceitaCsvParseResult(receitas: grupos.values.toList(), erros: erros);
}
