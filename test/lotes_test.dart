import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/core/printing/qr_svg.dart';
import 'package:gc_turnkey/src/features/products/domain/etiqueta.dart';
import 'package:gc_turnkey/src/features/traceability/domain/lote.dart';
import 'package:gc_turnkey/src/features/traceability/domain/rastreabilidade_html.dart';
import 'package:pocketbase/pocketbase.dart';

const _ataque = '</title><script>alert(1)</script><img src=x onerror=alert(2)>';

void main() {
  test('código do lote: data + 3 letras do produto + nº do dia', () {
    expect(codigoLote(DateTime(2026, 10, 6), 'Alba', 1), '261006-ALB-1');
    expect(
      codigoLote(DateTime(2026, 1, 5), 'Carolina do Sul', 3),
      '260105-CAR-3',
    );
    expect(codigoLote(DateTime(2026, 10, 6), 'Ñoquis & Cª', 2), '261006-NOQ-2');
    expect(codigoLote(DateTime(2026, 10, 6), 'Ab', 1), '261006-ABX-1');
    expect(codigoLote(DateTime(2026, 10, 6), '!!!', 1), '261006-PRD-1');
  });

  test('o endereço do QR leva ao lote (com o código codificado)', () {
    expect(
      urlDoLote('https://x.ts.net:8444', '261006-ALB-1'),
      'https://x.ts.net:8444/#/lote/261006-ALB-1',
    );
    expect(urlDoLote('https://x/', 'a b'), 'https://x/#/lote/a%20b');
  });

  test('lê um lote de produção do servidor', () {
    final l = LoteProducao.fromRecord(
      RecordModel({
        'id': 'l1',
        'codigo': '261006-ALB-1',
        'ficha': 'f1',
        'ficha_nome': 'Alba',
        'data_producao': '2026-10-06 00:00:00.000Z',
        'quantidade': 24,
        'validade': '2026-10-11 00:00:00.000Z',
        'ingredientes': [
          {
            'ingrediente': 'i1',
            'nome': 'Farinha',
            'lote': 'L1',
            'fornecedor': 'Makro',
            'validade': '2027-01-31',
          },
          {'ingrediente': 'i2', 'nome': 'Ovos', 'lote': ''},
        ],
      }),
    );
    expect(l.codigo, '261006-ALB-1');
    expect(l.dataProducao.day, 6);
    expect(l.ingredientes.length, 2);
    expect(l.semLote, 1);
    expect(l.ingredientes.first.validade!.year, 2027);
  });

  test('dataParaPb e o corpo do lote usado', () {
    expect(dataParaPb(DateTime(2026, 10, 6)), '2026-10-06 00:00:00.000Z');
    final j = LoteUsado(
      ingredienteId: 'i1',
      nome: 'Farinha',
      lote: 'L1',
      validade: DateTime(2027, 1, 31),
    ).toJson();
    expect(j['lote'], 'L1');
    expect(j['validade'], '2027-01-31');
  });

  test('o lote de ingrediente passa da validade', () {
    final l = LoteIngrediente(
      id: 'x',
      ingredienteId: 'i',
      lote: 'L',
      validade: DateTime(2026, 10, 5),
    );
    expect(l.passouValidade(DateTime(2026, 10, 6)), isTrue);
    expect(l.passouValidade(DateTime(2026, 10, 5)), isFalse);
  });

  test('QR em SVG: válido, determinístico e só com formas', () {
    final a = qrSvg('https://x.ts.net:8444/#/lote/261006-ALB-1');
    expect(a, startsWith('<svg'));
    expect(a, contains('<path d="M'));
    expect(a, isNot(contains('<script')));
    expect(qrSvg('https://x.ts.net:8444/#/lote/261006-ALB-1'), a);
    expect(qrSvg('outro texto'), isNot(a));
  });

  test('a ficha de rastreabilidade escapa o texto do utilizador (XSS)', () {
    final html = rastreabilidadeHtml(
      LoteProducao(
        id: 'l',
        codigo: _ataque,
        fichaNome: _ataque,
        dataProducao: DateTime(2026, 10, 6),
        responsavel: _ataque,
        notas: _ataque,
        ingredientes: [
          LoteUsado(
            ingredienteId: 'i',
            nome: _ataque,
            lote: _ataque,
            fornecedor: _ataque,
          ),
        ],
      ),
      empresa: _ataque,
      produtor: _ataque,
    );
    expect(html.contains('<script>alert'), isFalse);
    expect(html.contains('<img src=x'), isFalse);
    expect(html, contains('&lt;script&gt;'));
  });

  test('a etiqueta do lote leva o código e o QR; sem lote não leva QR', () {
    final qr = qrSvg('https://x.ts.net:8444/#/lote/261006-ALB-1');
    final com = etiquetaPagina(
      EtiquetaDados(
        nome: 'Alba',
        fabrico: DateTime(2026, 10, 6),
        lote: '261006-ALB-1',
        qrSvg: qr,
      ),
    );
    expect(com, contains('261006-ALB-1'));
    expect(com, contains('class="qr"'));
    expect(com, contains('<svg'));
    final sem = etiquetaPagina(
      EtiquetaDados(nome: 'Alba', fabrico: DateTime(2026, 10, 6)),
    );
    expect(sem, isNot(contains('class="qr"')));
    // lote sem QR (escrito à mão): só o texto
    final soTexto = etiquetaPagina(
      EtiquetaDados(nome: 'Alba', fabrico: DateTime(2026, 10, 6), lote: 'L1'),
    );
    expect(soTexto, contains('Lote:'));
    expect(soTexto, isNot(contains('class="qr"')));
  });
}
