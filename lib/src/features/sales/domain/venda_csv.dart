import 'package:csv/csv.dart';

import '../../tech_sheets/domain/tech_sheet.dart';
import 'match_ficha.dart';
import 'venda.dart';

/// As linhas de um único dia, extraídas de um CSV de vendas.
class VendaCsvGrupo {
  VendaCsvGrupo({required this.data, required this.itens});

  final DateTime data;
  final List<VendaItemInput> itens;

  double get total => itens.fold(0, (s, i) => s + i.totalLinha);
  int get naoIdentificados => itens.where((i) => i.fichaId == null).length;
}

/// Resultado da leitura de um CSV de vendas — um [VendaCsvGrupo] por dia
/// distinto encontrado, mais os erros de linhas que não se conseguiu ler.
class VendaCsvParseResult {
  VendaCsvParseResult({List<VendaCsvGrupo>? grupos, List<String>? erros})
      : grupos = grupos ?? [],
        erros = erros ?? [];

  final List<VendaCsvGrupo> grupos;
  final List<String> erros;

  int get totalLinhas => grupos.fold(0, (s, g) => s + g.itens.length);
  int get totalNaoIdentificados =>
      grupos.fold(0, (s, g) => s + g.naoIdentificados);
  bool get vazio => grupos.isEmpty;
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

DateTime? _parseData(String v) {
  final s = _clean(v);
  if (s.isEmpty) return null;
  // aceita "2026-09-14" (ISO) e "14/09/2026" ou "14-09-2026" (PT)
  final iso = DateTime.tryParse(s);
  if (iso != null) return iso;
  final m = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$').firstMatch(s);
  if (m != null) {
    final d = int.tryParse(m.group(1)!);
    final mo = int.tryParse(m.group(2)!);
    final y = int.tryParse(m.group(3)!);
    if (d != null && mo != null && y != null) return DateTime(y, mo, d);
  }
  return null;
}

/// Lê um CSV de vendas — colunas `data, produto, quantidade,
/// preco_unitario` (separado por vírgula; `€` e vírgula decimal tolerados;
/// cabeçalho opcional, detetado se a 1ª célula for "data"/"date"/"dia").
/// Cada linha é associada à ficha técnica cujo nome melhor corresponde a
/// `produto` (`melhorMatchFicha`); sem correspondência com confiança
/// suficiente, a linha fica sem ficha (`descricao` guarda o texto original).
VendaCsvParseResult parseVendasCsv(String content, List<FichaTecnica> fichas) {
  final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final rows = const CsvToListConverter(
    fieldDelimiter: ',',
    eol: '\n',
    shouldParseNumbers: false,
    allowInvalid: true,
  ).convert(normalized.trim());

  final porDia = <String, List<VendaItemInput>>{};
  final erros = <String>[];

  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    if (row.length < 4) continue;
    final primeira = _clean(row[0]).toLowerCase();
    if (i == 0 &&
        (primeira == 'data' || primeira == 'date' || primeira == 'dia')) {
      continue; // cabeçalho
    }

    final data = _parseData(row[0].toString());
    final produto = _clean(row[1]);
    final quantidade = _parseNum(row[2]);
    final preco = _parseNum(row[3]);

    if (data == null || produto.isEmpty || quantidade == null || preco == null) {
      erros.add('Linha ${i + 1}: dados inválidos ("${row.join(', ')}").');
      continue;
    }

    final ficha = fichaParaVenda(produto, fichas);
    final chave = ymd(data);
    (porDia[chave] ??= []).add(
      VendaItemInput(
        fichaId: ficha?.id,
        descricao: produto,
        quantidade: quantidade,
        precoUnitario: preco,
        custoUnitarioSnapshot: ficha?.custoProduto ?? 0,
      ),
    );
  }

  final grupos = porDia.entries
      .map((e) => VendaCsvGrupo(data: DateTime.parse(e.key), itens: e.value))
      .toList()
    ..sort((a, b) => a.data.compareTo(b.data));

  return VendaCsvParseResult(grupos: grupos, erros: erros);
}
