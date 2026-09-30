import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/finance/domain/equipamento_csv.dart';

void main() {
  test('lê cabeçalho e cria um EquipamentoInput por linha', () {
    const csv = '''
Equipamento,Custo,Vida útil (anos)
Computador,500,3
Mesas,377.93,5
''';
    final r = parseEquipamentosCsv(csv);
    expect(r.erros, isEmpty);
    expect(r.itens, hasLength(2));

    expect(r.itens[0].nome, 'Computador');
    expect(r.itens[0].custo, closeTo(500, 0.001));
    expect(r.itens[0].vidaUtilAnos, closeTo(3, 0.001));
    // custo mensal recalcula-se sempre a partir de custo/vida útil.
    expect(r.itens[0].custoMensal, closeTo(500 / 36, 0.001));

    expect(r.itens[1].nome, 'Mesas');
  });

  test('sem cabeçalho também funciona', () {
    const csv = 'Forno,890.21,5';
    final r = parseEquipamentosCsv(csv);
    expect(r.itens, hasLength(1));
    expect(r.itens.single.nome, 'Forno');
    expect(r.itens.single.custo, closeTo(890.21, 0.001));
    expect(r.itens.single.vidaUtilAnos, closeTo(5, 0.001));
  });

  test('€ e vírgula decimal são tolerados', () {
    const csv = 'Balcão,"€ 1500,00",5';
    final r = parseEquipamentosCsv(csv);
    expect(r.itens.single.custo, closeTo(1500, 0.001));
  });

  test('linha sem vida útil ou custo inválido vai para erros', () {
    const csv = '''
Forno,890.21,5
Balcão,1500,0
Vitrine,abc,3
''';
    final r = parseEquipamentosCsv(csv);
    expect(r.erros, hasLength(2));
    expect(r.itens, hasLength(1));
  });

  test('texto colado com tab (folha de cálculo) e notas na 4ª coluna', () {
    const texto = 'Forno\t€890,21\t5\tcomprado em saldo';
    final r = parseEquipamentosCsv(texto);
    expect(r.erros, isEmpty);
    expect(r.itens.single.nome, 'Forno');
    expect(r.itens.single.custo, closeTo(890.21, 0.001));
    expect(r.itens.single.vidaUtilAnos, closeTo(5, 0.001));
    expect(r.itens.single.notas, 'comprado em saldo');
  });

  test('delimitador ";" também funciona e notas fica vazia sem 4ª coluna', () {
    const texto = 'Vitrine;420;3';
    final r = parseEquipamentosCsv(texto);
    expect(r.itens.single.notas, isEmpty);
  });

  test('linhas em branco no meio do texto colado são ignoradas', () {
    const texto = 'Computador\t500\t3\n\nVitrine\t420\t3\n';
    final r = parseEquipamentosCsv(texto);
    expect(r.itens, hasLength(2));
    expect(r.erros, isEmpty);
  });
}
