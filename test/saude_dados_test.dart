import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/data_health/domain/saude_dados.dart';
import 'package:gc_turnkey/src/features/ingredients/domain/ingredient.dart';
import 'package:gc_turnkey/src/features/tech_sheets/domain/tech_sheet.dart';

void main() {
  FichaTecnica ficha(
    String id, {
    String nome = 'Alba',
    double preco = 0,
    double custo = 0,
    int tempo = 0,
    int temp = 0,
    bool deletado = false,
    String sub = '',
  }) => FichaTecnica(
    id: id,
    nome: nome,
    subnome: sub,
    precoVenda: preco,
    custoProduto: custo,
    tempoAssaduraMin: tempo,
    temperaturaFornoC: temp,
    deletado: deletado,
  );

  Ingrediente ing(
    String id, {
    String nome = 'Farinha',
    double preco = 0,
    bool deletado = false,
    OrigemIngrediente origem = OrigemIngrediente.comprado,
    bool nutriIrrelevante = true,
  }) => Ingrediente(
    id: id,
    nome: nome,
    preco: preco,
    deletado: deletado,
    origem: origem,
    nutriIrrelevante: nutriIrrelevante,
  );

  test('uma ficha completa não dá problemas', () {
    final r = analisarDados(
      fichas: [ficha('a', preco: 3, custo: 1, tempo: 11, temp: 170)],
      ingredientes: [ing('i', preco: 2)],
    );
    expect(r.problemas, isEmpty);
    expect(r.completoPct, 100);
    expect(r.essenciais, 0);
  });

  test('cada coisa em falta aparece no seu grupo', () {
    final r = analisarDados(
      fichas: [
        ficha('a', nome: 'Alba', sub: 'Kinder', custo: 1, tempo: 11),
        ficha('b', nome: 'Belém', preco: 3, custo: 1, tempo: 11, temp: 170),
      ],
      ingredientes: [],
    );
    expect(r.de(TipoProblema.fichaSemPreco).map((p) => p.nome), [
      'Alba · Kinder',
    ]);
    expect(r.de(TipoProblema.fichaSemTemperatura).map((p) => p.id), ['a']);
    expect(r.de(TipoProblema.fichaSemTempo), isEmpty);
    expect(r.de(TipoProblema.fichaSemCusto), isEmpty);
    expect(r.essenciais, 1); // só o preço é "essencial"
  });

  test('ingredientes: sem preço (só os comprados) e sem nutrição', () {
    final r = analisarDados(
      fichas: [],
      ingredientes: [
        ing('a', nome: 'Manteiga'),
        ing('b', nome: 'Massa base', origem: OrigemIngrediente.fabricoProprio),
        ing('c', nome: 'Açúcar', preco: 1.2, nutriIrrelevante: false),
      ],
    );
    expect(r.de(TipoProblema.ingredienteSemPreco).map((p) => p.nome), [
      'Manteiga',
    ]);
    expect(r.de(TipoProblema.ingredienteSemNutricao).map((p) => p.nome), [
      'Açúcar',
    ]);
  });

  test('o que está na lixeira não conta', () {
    final r = analisarDados(
      fichas: [ficha('a', deletado: true)],
      ingredientes: [ing('i', deletado: true)],
    );
    expect(r.problemas, isEmpty);
    expect(r.fichas, 0);
    expect(r.ingredientes, 0);
  });

  test('a percentagem completa conta as verificações', () {
    // 1 ficha (4 verificações) com 2 em falta; 1 ingrediente (2) com 0 em falta
    final r = analisarDados(
      fichas: [ficha('a', preco: 3, custo: 1)],
      ingredientes: [ing('i', preco: 2)],
    );
    expect(r.verificacoes, 6);
    expect(r.problemas, hasLength(2));
    expect(r.completoPct, closeTo(66.6667, 1e-3));
    expect(
      const RelatorioSaude(
        problemas: [],
        fichas: 0,
        ingredientes: 0,
      ).completoPct,
      100,
    );
  });

  test('ordem: por tipo e depois por nome', () {
    final r = analisarDados(
      fichas: [
        ficha('b', nome: 'Zeta'),
        ficha('a', nome: 'alfa'),
      ],
      ingredientes: [],
    );
    final semPreco = r.problemas
        .where((p) => p.tipo == TipoProblema.fichaSemPreco)
        .map((p) => p.nome);
    expect(semPreco, ['alfa', 'Zeta']);
    expect(r.problemas.first.tipo, TipoProblema.fichaSemPreco);
    expect(TipoProblema.fichaSemPreco.eFicha, isTrue);
    expect(TipoProblema.ingredienteSemPreco.eFicha, isFalse);
  });
}
