import 'package:flutter_test/flutter_test.dart';
import 'package:turnkey_app/src/features/products/domain/lista_ingredientes.dart';
import 'package:turnkey_app/src/features/products/domain/produto_gookie.dart';
import 'package:turnkey_app/src/features/tech_sheets/domain/tech_sheet.dart';

void main() {
  group('ListaIngredientes', () {
    test('ordem decrescente de peso e alergénios destacados', () {
      final l = ListaIngredientes.de(const [
        IngredienteRotulo(nome: 'sal', gramas: 2),
        IngredienteRotulo(nome: 'farinha de trigo', gramas: 500, alergenios: ['Glúten']),
        IngredienteRotulo(nome: 'açúcar', gramas: 200),
        IngredienteRotulo(nome: 'manteiga', gramas: 300, alergenios: ['Leite']),
      ]);
      expect(l.itens.map((i) => i.nome).toList(),
          ['farinha de trigo', 'manteiga', 'açúcar', 'sal']);
      expect(
        l.textoSimples,
        'Farinha de trigo (GLÚTEN), manteiga (LEITE), açúcar, sal',
      );
      final negritos =
          l.segmentos.where((s) => s.negrito).map((s) => s.texto).toList();
      expect(negritos, ['GLÚTEN', 'LEITE']);
      expect(l.alergenios, {'Glúten', 'Leite'});
    });

    test('nomes repetidos somam-se e juntam alergénios', () {
      final l = ListaIngredientes.de(const [
        IngredienteRotulo(nome: 'Chocolate', gramas: 100, alergenios: ['Leite']),
        IngredienteRotulo(nome: 'chocolate ', gramas: 50, alergenios: ['Soja']),
        IngredienteRotulo(nome: 'Ovo', gramas: 120),
      ]);
      expect(l.itens.length, 2);
      expect(l.itens.first.nome, 'Chocolate');
      expect(l.itens.first.gramas, 150);
      expect(l.itens.first.alergenios, ['Leite', 'Soja']);
      expect(l.textoSimples, 'Chocolate (LEITE, SOJA), Ovo');
    });

    test('ignora linhas sem nome ou sem peso; empate por nome', () {
      final l = ListaIngredientes.de(const [
        IngredienteRotulo(nome: '', gramas: 10),
        IngredienteRotulo(nome: 'Água', gramas: 0),
        IngredienteRotulo(nome: 'Zimbro', gramas: 5),
        IngredienteRotulo(nome: 'Anis', gramas: 5),
      ]);
      expect(l.itens.map((i) => i.nome).toList(), ['Anis', 'Zimbro']);
      expect(ListaIngredientes.de(const []).vazia, isTrue);
    });
  });

  group('pendenciasProduto', () {
    test('ficha vazia: falta tudo', () {
      const f = FichaTecnica(id: '1', nome: 'Boston');
      expect(pendenciasProduto(f), [
        'Sem informação nutricional',
        'Sem descrição',
        'Sem prazo de validade',
        'Sem modo de conservação',
      ]);
      expect(nutricaoCompleta(f), isFalse);
    });

    test('dados preenchidos e nutrição completa: sem pendências', () {
      final f = FichaTecnica(
        id: '1',
        nome: 'Boston',
        descricao: 'Cookie recheado',
        validadeDias: 5,
        conservacao: 'Local fresco e seco',
        nutriRaw: const {
          'por100g': {'energia_kcal': 400, 'lipidos_g': 20},
          'completo': true,
        },
      );
      // só passa se o NutriCache reconhecer estes campos
      final p = pendenciasProduto(f);
      expect(p.contains('Sem descrição'), isFalse);
      expect(p.contains('Sem prazo de validade'), isFalse);
      expect(p.contains('Sem modo de conservação'), isFalse);
    });
  });
}
