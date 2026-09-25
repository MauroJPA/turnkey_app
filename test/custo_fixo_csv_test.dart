import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/finance/domain/custo_fixo.dart';
import 'package:gc_turnkey/src/features/finance/domain/custo_fixo_csv.dart';

void main() {
  test('lê cabeçalho e cria um CustoFixoInput fixo por linha', () {
    const csv = '''
nome,valor,dia_pagamento
Energia,140,8
Internet,69,
''';
    final r = parseCustosFixosCsv(csv);
    expect(r.erros, isEmpty);
    expect(r.itens, hasLength(2));

    expect(r.itens[0].nome, 'Energia');
    expect(r.itens[0].tipo, TipoCusto.fixo);
    expect(r.itens[0].valorMensal, closeTo(140, 0.001));
    expect(r.itens[0].diaPagamento, 8);

    expect(r.itens[1].nome, 'Internet');
    expect(r.itens[1].diaPagamento, isNull);
  });

  test('sem cabeçalho também funciona (1ª célula não é "nome")', () {
    const csv = 'Água,45';
    final r = parseCustosFixosCsv(csv);
    expect(r.itens, hasLength(1));
    expect(r.itens.single.nome, 'Água');
    expect(r.itens.single.valorMensal, closeTo(45, 0.001));
  });

  test('€ e vírgula decimal são tolerados no valor', () {
    const csv = 'Contabilista,"€ 120,00"';
    final r = parseCustosFixosCsv(csv);
    expect(r.itens.single.valorMensal, closeTo(120, 0.001));
  });

  test('linha com valor inválido ou negativo vai para erros', () {
    const csv = '''
Energia,140
Internet,abc
''';
    final r = parseCustosFixosCsv(csv);
    expect(r.erros, hasLength(1));
    expect(r.itens, hasLength(1));
  });

  test('dia de pagamento fora de 1-31 é ignorado (fica null)', () {
    const csv = 'Energia,140,45';
    final r = parseCustosFixosCsv(csv);
    expect(r.itens.single.diaPagamento, isNull);
  });
}
