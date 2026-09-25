import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/core/formatting/quantities.dart';
import 'package:gc_turnkey/src/features/ingredients/domain/ingredient.dart';
import 'package:gc_turnkey/src/features/invoices/domain/fatura.dart';
import 'package:gc_turnkey/src/features/invoices/domain/match_ingrediente.dart';
import 'package:gc_turnkey/src/features/recipes/domain/recipe_item.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  test('quantidadeParaTexto por unidade', () {
    expect(quantidadeParaTexto(800, 'g'), '800 g');
    expect(quantidadeParaTexto(1500, null), '1,5 kg');
    expect(quantidadeParaTexto(250, 'ml'), '250 ml');
    expect(quantidadeParaTexto(1500, 'ml'), '1,5 L');
    expect(quantidadeParaTexto(12, 'un'), '12 un');
    expect(quantidadeParaTexto(2.5, 'un'), '2,5 un');
    expect(unidadeNormalizada('xx'), 'g');
  });

  test('Ingrediente: unidade normalizada e nome com característica', () {
    const a = Ingrediente(
      id: '1',
      nome: 'Farinha de trigo',
      caracteristica: 'T55',
      unidade: 'ml',
    );
    expect(a.nomeComCaracteristica, 'Farinha de trigo T55');
    expect(a.un, 'ml');
    expect(
      const Ingrediente(id: '2', nome: 'Sal').nomeComCaracteristica,
      'Sal',
    );
    expect(const Ingrediente(id: '2', nome: 'Sal').un, 'g');
  });

  test('linha da IA: unidade da embalagem, característica e volume', () {
    final l = FaturaLinhaIa.fromJson(const {
      'descricao': 'Farinha T55 1kg',
      'nome_generico': 'Farinha de trigo',
      'caracteristica': 'T55',
      'quantidade': 2,
      'unidade': 'un',
      'embalagem_g': 1000,
    });
    expect(l.embalagemUnidade, 'g');
    expect(l.caracteristica, 'T55');
    final leite = FaturaLinhaIa.fromJson(const {
      'descricao': 'Leite 1L',
      'quantidade': 6,
      'unidade': 'un',
      'embalagem_g': 1000,
      'embalagem_unidade': 'ml',
    });
    expect(leite.embalagemUnidade, 'ml');
    expect(leite.quantidadeG, 6000);
    final litros = FaturaLinhaIa.fromJson(const {
      'descricao': 'Óleo',
      'quantidade': 5,
      'unidade': 'L',
    });
    expect(litros.unidadeEVolume, isTrue);
    expect(litros.quantidadeG, 5000);
  });

  group('emparelhar com característica', () {
    const t55 = Ingrediente(
      id: 't55',
      nome: 'Farinha de trigo',
      caracteristica: 'T55',
    );
    const t65 = Ingrediente(
      id: 't65',
      nome: 'Farinha de trigo',
      caracteristica: 'T65',
    );
    const simples = Ingrediente(id: 's', nome: 'Farinha de trigo');

    test('a característica escolhe a variedade certa', () {
      final m = emparelharLinha(
        descricao: 'Farinha trigo T65 saco 1kg',
        nomeGenerico: 'Farinha de trigo',
        caracteristica: 'T65',
        ingredientes: const [t55, t65],
        produtos: const [],
      );
      expect(m?.ingrediente.id, 't65');
    });

    test('característica que não existe não cai noutra variedade', () {
      final m = emparelharLinha(
        descricao: 'Farinha de trigo T45',
        nomeGenerico: 'Farinha de trigo',
        caracteristica: 'T45',
        ingredientes: const [t55, t65],
        produtos: const [],
      );
      expect(m, isNull);
    });

    test('sem característica lida usa o ingrediente sem característica', () {
      final m = emparelharLinha(
        descricao: 'Farinha de trigo',
        nomeGenerico: 'Farinha de trigo',
        ingredientes: const [t55, simples],
        produtos: const [],
      );
      expect(m?.ingrediente.id, 's');
    });
  });

  test('linha de receita: peso em gramas por unidade/ml', () {
    RecordModel r(String unidade, Map<String, dynamic> extra) =>
        RecordModel.fromJson({
          'id': 'l',
          'receita': 'r',
          'ingrediente': 'i',
          'quantidade_g': 2,
          'expand': {
            'ingrediente': {
              'id': 'i',
              'nome': 'x',
              'preco': 3,
              'gramas_embalagem': 12,
              'unidade': unidade,
              ...extra,
            },
          },
        });
    final ovo = ItemReceita.fromRecord(r('un', {'gramas_unidade': 50}));
    expect(ovo.unidade, 'un');
    expect(ovo.pesoG, 100);
    expect(ovo.custoLinha, closeTo(0.5, 1e-9)); // custo na unidade nativa
    final leite = ItemReceita.fromRecord(r('ml', {'nutri_densidade': 1.2}));
    expect(leite.pesoG, closeTo(2.4, 1e-9));
    final farinha = ItemReceita.fromRecord(r('g', {}));
    expect(farinha.pesoG, 2);
  });
}
