import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/sales/domain/venda_csv.dart';
import 'package:gc_turnkey/src/features/tech_sheets/domain/tech_sheet.dart';

FichaTecnica _ficha(String id, String nome, {double custoProduto = 0}) =>
    FichaTecnica(id: id, nome: nome, custoProduto: custoProduto);

void main() {
  final fichas = [
    _ficha('f1', 'Cookie de Chocolate', custoProduto: 1.2),
    _ficha('f2', 'Cookie de Baunilha'),
    _ficha('f3', 'Brownie'),
  ];

  test('lê cabeçalho, agrupa por dia e associa por nome parecido', () {
    const csv = '''
data,produto,quantidade,preco_unitario
2026-09-01,Cookie de Chocolate,3,2.50
2026-09-01,Brownie,1,3.00
2026-09-02,Cookie Baunilha,2,2.50
''';
    final r = parseVendasCsv(csv, fichas);
    expect(r.erros, isEmpty);
    expect(r.grupos.length, 2);

    final dia1 = r.grupos[0];
    expect(dia1.data, DateTime(2026, 9, 1));
    expect(dia1.itens.length, 2);
    expect(dia1.itens[0].fichaId, 'f1');
    expect(dia1.itens[0].custoUnitarioSnapshot, 1.2);
    expect(dia1.itens[1].fichaId, 'f3');
    expect(dia1.total, closeTo(3 * 2.50 + 1 * 3.00, 0.001));

    final dia2 = r.grupos[1];
    expect(dia2.itens.single.fichaId, 'f2'); // "Cookie Baunilha" ~ "Cookie de Baunilha"
  });

  test('sem cabeçalho também funciona (1ª célula não é "data")', () {
    const csv = '14/09/2026,Brownie,2,3.00';
    final r = parseVendasCsv(csv, fichas);
    expect(r.grupos, hasLength(1));
    expect(r.grupos.single.data, DateTime(2026, 9, 14));
  });

  test('€ e vírgula decimal são tolerados no preço', () {
    const csv = '2026-09-01,Brownie,1,"€ 3,50"';
    final r = parseVendasCsv(csv, fichas);
    expect(r.grupos.single.itens.single.precoUnitario, closeTo(3.50, 0.001));
  });

  test('produto sem correspondência fica sem ficha (mas não é erro)', () {
    const csv = '2026-09-01,Batido de morango,1,2.00';
    final r = parseVendasCsv(csv, fichas);
    expect(r.erros, isEmpty);
    final item = r.grupos.single.itens.single;
    expect(item.fichaId, isNull);
    expect(item.descricao, 'Batido de morango');
    expect(item.custoUnitarioSnapshot, 0);
    expect(r.totalNaoIdentificados, 1);
  });

  test('linha com dados inválidos vai para erros, não trava o resto', () {
    const csv = '''
2026-09-01,Brownie,1,3.00
data-invalida,Brownie,1,3.00
''';
    final r = parseVendasCsv(csv, fichas);
    expect(r.erros, hasLength(1));
    expect(r.grupos.single.itens, hasLength(1));
  });
}
