import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';

import 'relatorio_geral.dart';

/// Escreve o relatório num ficheiro Excel (.xlsx) com **uma folha por
/// relatório**. Sem dependências além do `archive`: um .xlsx é um zip de XMLs.
List<int> relatorioXlsx(List<FolhaRelatorio> folhas) {
  final nomes = _nomesDeFolhas(folhas);
  final arq = Archive();
  void add(String caminho, String conteudo) {
    final bytes = utf8.encode(conteudo);
    arq.addFile(ArchiveFile(caminho, bytes.length, bytes));
  }

  const ns = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
  const nsR =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
  const cab = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';

  add(
    '[Content_Types].xml',
    '$cab<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
        '${[for (var i = 1; i <= folhas.length; i++) '<Override PartName="/xl/worksheets/sheet$i.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'].join()}'
        '</Types>',
  );
  add(
    '_rels/.rels',
    '$cab<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
        '</Relationships>',
  );
  add(
    'xl/workbook.xml',
    '$cab<workbook xmlns="$ns" xmlns:r="$nsR"><sheets>'
        '${[for (var i = 0; i < folhas.length; i++) '<sheet name="${_xml(nomes[i])}" sheetId="${i + 1}" r:id="rId${i + 1}"/>'].join()}'
        '</sheets></workbook>',
  );
  add(
    'xl/_rels/workbook.xml.rels',
    '$cab<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '${[for (var i = 1; i <= folhas.length; i++) '<Relationship Id="rId$i" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet$i.xml"/>'].join()}'
        '<Relationship Id="rId${folhas.length + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
        '</Relationships>',
  );
  add(
    'xl/styles.xml',
    '$cab<styleSheet xmlns="$ns">'
        '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font>'
        '<font><b/><sz val="11"/><name val="Calibri"/></font></fonts>'
        '<fills count="2"><fill><patternFill patternType="none"/></fill>'
        '<fill><patternFill patternType="gray125"/></fill></fills>'
        '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
        '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
        '<cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
        '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs>'
    '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
        '</styleSheet>',
  );

  for (var i = 0; i < folhas.length; i++) {
    add('xl/worksheets/sheet${i + 1}.xml', _folhaXml(folhas[i], cab, ns));
  }
  final zip = ZipEncoder().encode(arq);
  return zip ?? const [];
}

/// Um .zip com um .csv (UTF-8, separador vírgula) por folha.
List<int> relatorioCsvZip(List<FolhaRelatorio> folhas) {
  final arq = Archive();
  const conv = ListToCsvConverter(fieldDelimiter: ',', eol: '\r\n');
  for (var i = 0; i < folhas.length; i++) {
    final f = folhas[i];
    final linhas = <List<String>>[
      f.colunas,
      for (final l in f.linhas) [for (final v in l) _csvValor(v)],
    ];
    final bytes = utf8.encode(conv.convert(linhas));
    final nome = '${(i + 1).toString().padLeft(2, '0')}-${_slug(f.nome)}.csv';
    arq.addFile(ArchiveFile(nome, bytes.length, bytes));
  }
  return ZipEncoder().encode(arq) ?? const [];
}

String _csvValor(Object? v) {
  if (v == null) return '';
  if (v is bool) return v ? 'sim' : 'não';
  if (v is int) return '$v';
  if (v is double) {
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }
  return '$v';
}

String _slug(String s) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const para = 'aaaaaeeeeiiiiooooouuuucn';
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    final i = de.indexOf(c);
    b.write(i >= 0 ? para[i] : c);
  }
  return b
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

/// Nomes de folha válidos no Excel: até 31 caracteres, sem `[]:*?/\`, únicos.
List<String> _nomesDeFolhas(List<FolhaRelatorio> folhas) {
  final usados = <String>{};
  final out = <String>[];
  for (final f in folhas) {
    var n = f.nome.replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ').trim();
    if (n.isEmpty) n = 'Folha';
    if (n.length > 31) n = n.substring(0, 31);
    var candidato = n;
    var k = 2;
    while (usados.contains(candidato.toLowerCase())) {
      final sufixo = ' $k';
      candidato =
          '${n.substring(0, n.length.clamp(0, 31 - sufixo.length))}$sufixo';
      k++;
    }
    usados.add(candidato.toLowerCase());
    out.add(candidato);
  }
  return out;
}

String _xml(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    // caracteres de controlo (exceto tab, LF, CR) não são válidos em XML
    if (r < 0x20 && r != 0x09 && r != 0x0A && r != 0x0D) continue;
    switch (r) {
      case 0x26:
        b.write('&amp;');
      case 0x3C:
        b.write('&lt;');
      case 0x3E:
        b.write('&gt;');
      case 0x22:
        b.write('&quot;');
      default:
        b.writeCharCode(r);
    }
  }
  return b.toString();
}

/// "A", "B", … "Z", "AA"…
String _coluna(int i) {
  var n = i + 1;
  final b = StringBuffer();
  while (n > 0) {
    final r = (n - 1) % 26;
    b.write(String.fromCharCode(65 + r));
    n = (n - 1) ~/ 26;
  }
  return b.toString().split('').reversed.join();
}

String _celula(int col, int linha, Object? v, {bool negrito = false}) {
  final ref = '${_coluna(col)}$linha';
  final s = negrito ? ' s="1"' : '';
  if (v == null) return '';
  if (v is bool) return '<c r="$ref"$s t="b"><v>${v ? 1 : 0}</v></c>';
  if (v is num) {
    if (v is double && !v.isFinite) return '';
    return '<c r="$ref"$s><v>$v</v></c>';
  }
  return '<c r="$ref"$s t="inlineStr"><is><t xml:space="preserve">${_xml('$v')}</t></is></c>';
}

String _folhaXml(FolhaRelatorio f, String cab, String ns) {
  // larguras: o maior texto da coluna (limitado)
  final larguras = [
    for (var c = 0; c < f.colunas.length; c++)
      () {
        var m = f.colunas[c].length;
        for (final l in f.linhas) {
          if (c < l.length && l[c] != null) {
            final t = '${l[c]}'.length;
            if (t > m) m = t;
          }
        }
        return (m + 2).clamp(8, 60);
      }(),
  ];
  final b = StringBuffer(cab)
    ..write('<worksheet xmlns="$ns">')
    ..write(
      '<sheetViews><sheetView workbookViewId="0">'
      '<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>'
      '</sheetView></sheetViews>',
    )
    ..write('<cols>');
  for (var c = 0; c < larguras.length; c++) {
    b.write(
      '<col min="${c + 1}" max="${c + 1}" width="${larguras[c]}" customWidth="1"/>',
    );
  }
  b.write('</cols><sheetData>');
  b.write('<row r="1">');
  for (var c = 0; c < f.colunas.length; c++) {
    b.write(_celula(c, 1, f.colunas[c], negrito: true));
  }
  b.write('</row>');
  for (var r = 0; r < f.linhas.length; r++) {
    final l = f.linhas[r];
    b.write('<row r="${r + 2}">');
    for (var c = 0; c < l.length; c++) {
      b.write(_celula(c, r + 2, l[c]));
    }
    b.write('</row>');
  }
  b.write('</sheetData></worksheet>');
  return b.toString();
}
