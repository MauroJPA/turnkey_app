import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/core/nutrition/nutri_widgets.dart';
import 'package:gc_turnkey/src/core/nutrition/nutrition.dart';
import 'package:gc_turnkey/src/core/printing/html_escape.dart';
import 'package:gc_turnkey/src/features/orders/domain/configuracao_encomendas.dart';
import 'package:gc_turnkey/src/features/orders/domain/encomenda.dart';
import 'package:gc_turnkey/src/features/orders/presentation/encomenda_talao.dart';
import 'package:gc_turnkey/src/features/products/domain/etiqueta.dart';
import 'package:gc_turnkey/src/features/tech_sheets/domain/tech_sheet.dart';

const _ataque = '</title><script>alert(1)</script><img src=x onerror=alert(2)>"\'';

bool _perigoso(String html) =>
    html.contains('<script>alert') ||
    html.contains('<img src=x') ||
    html.contains('</title><script');

void main() {
  test('escaparHtml neutraliza etiquetas e aspas', () {
    final r = escaparHtml(_ataque);
    expect(r.contains('<'), isFalse);
    expect(r.contains('>'), isFalse);
    expect(r.contains('"'), isFalse);
    expect(r, contains('&lt;script&gt;'));
  });

  test('o título da página de impressão é escapado (XSS no talão)', () {
    // print_html.dart usa dart:html (só web): confirma no código-fonte.
    final src = File('lib/src/core/printing/print_html.dart').readAsStringSync();
    expect(src, contains('<title>\${escaparHtml(tituloPagina)}</title>'));
    expect(src.contains('<title>\$tituloPagina</title>'), isFalse);
  });

  test('declaração nutricional: nome do produto malicioso', () {
    final h = declaracaoHtml(
      titulo: _ataque,
      por100g: const Nutrientes(kcal: 100),
      alergenios: const ['Leite'],
      alergeniosTracos: const [_ataque],
    );
    expect(_perigoso(h), isFalse);
  });

  test('etiqueta: nome, descrição, conservação, lote, produtor e ingredientes maliciosos', () {
    final h = etiquetaPagina(EtiquetaDados(
      nome: _ataque,
      descricao: _ataque,
      conservacao: _ataque,
      lote: _ataque,
      produtor: _ataque,
      tracos: const [_ataque],
      fabrico: DateTime(2026, 1, 1),
    ));
    expect(_perigoso(h), isFalse);
  });

  test('talão da encomenda: cliente, notas, empresa e produtos maliciosos', () {
    final e = Encomenda(
      id: 'e1',
      clienteNome: _ataque,
      clienteTelefone: _ataque,
      clienteNotas: _ataque,
      notas: _ataque,
      dataHora: DateTime(2026, 1, 1, 10),
    );
    final itens = [
      EncomendaItem(id: 'i1', encomendaId: 'e1', fichaId: 'f1', quantidade: 2, notas: _ataque),
    ];
    final fichas = [FichaTecnica(id: 'f1', nome: _ataque)];
    final h = talaoHtml(e, itens, fichas, _ataque, TalaoTamanho.termico80, (v) => v.toString());
    expect(_perigoso(h), isFalse);
  });
}
