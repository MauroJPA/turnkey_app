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

  group('lista completa vs resumida', () {
    // O exemplo do Mauro (Provença): pesos por ordem decrescente.
    final l = ListaIngredientes.de(const [
      IngredienteRotulo(nome: 'Farinha de trigo T55', gramas: 400, alergenios: ['Glúten']),
      IngredienteRotulo(nome: 'Chocolate Branco 30% Chocovic', gramas: 300, marca: 'Chocovic'),
      IngredienteRotulo(nome: 'Manteiga', gramas: 250, alergenios: ['Leite']),
      IngredienteRotulo(nome: 'Açucar Amarelo', gramas: 120),
      IngredienteRotulo(nome: 'Leite Condensado', gramas: 200, alergenios: ['Leite']),
      IngredienteRotulo(nome: 'Açucar Branco', gramas: 110),
      IngredienteRotulo(nome: 'Ovo liquido', gramas: 100, alergenios: ['Ovos']),
      IngredienteRotulo(nome: 'Nata', gramas: 90, alergenios: ['Leite']),
      IngredienteRotulo(nome: 'Framboesa Congelada', gramas: 80),
      IngredienteRotulo(nome: 'Ginja Congelada', gramas: 70),
      IngredienteRotulo(nome: 'Mirtilo Congelado', gramas: 60),
      IngredienteRotulo(nome: 'Morango Congelado', gramas: 50),
      IngredienteRotulo(nome: 'Sumo de Limão', gramas: 30),
      IngredienteRotulo(nome: 'Fermento em Pó', gramas: 20),
      IngredienteRotulo(nome: 'Raspas de Limão', gramas: 10),
      IngredienteRotulo(nome: 'Bicarbonato de Sódio', gramas: 8),
      IngredienteRotulo(nome: 'Sal Grosso Iodado', gramas: 5),
    ]);

    test('completa: nomes tal como estão (congelado, marca, %)', () {
      expect(
        l.textoSimples,
        'Farinha de trigo T55 (GLÚTEN), Chocolate Branco 30% Chocovic, '
        'Manteiga (LEITE), LEITE Condensado, Açucar Amarelo, '
        'Açucar Branco, OVO liquido, Nata (LEITE), '
        'Framboesa Congelada, Ginja Congelada, Mirtilo Congelado, '
        'Morango Congelado, Sumo de Limão, Fermento em Pó, Raspas de Limão, '
        'Bicarbonato de Sódio, Sal Grosso Iodado',
      );
    });

    test('resumida: nomes curtos, variantes e limão juntos', () {
      expect(
        l.resumida().textoSimples,
        'Farinha de trigo (GLÚTEN), Chocolate Branco, Manteiga (LEITE), '
        'Açucar amarelo e branco, LEITE Condensado, OVOS, '
        'Nata (LEITE), Framboesa, Ginja, Mirtilo, Morango, Limão, Fermento, '
        'Bicarbonato de Sódio, Sal Grosso',
      );
    });

    test('alergénio já no nome: destaca a palavra, sem repetir', () {
      final r = ListaIngredientes.de(const [
        IngredienteRotulo(nome: 'Leite condensado', gramas: 300, alergenios: ['Leite']),
        IngredienteRotulo(nome: 'Chocolate de leite', gramas: 200, alergenios: ['Leite', 'Soja']),
        IngredienteRotulo(nome: 'Ovo liquido', gramas: 100, alergenios: ['Ovos']),
        IngredienteRotulo(nome: 'Manteiga', gramas: 50, alergenios: ['Leite']),
      ]);
      expect(
        r.textoSimples,
        'LEITE condensado, Chocolate de LEITE (SOJA), OVO liquido, Manteiga (LEITE)',
      );
      final negritos = r.segmentos.where((s) => s.negrito).map((s) => s.texto).toList();
      expect(negritos, ['LEITE', 'LEITE', 'SOJA', 'OVO', 'LEITE']);
      expect(r.alergenios, {'Leite', 'Soja', 'Ovos'});
    });

    test('nomeRotulo manda sobre o nome deduzido', () {
      final r = ListaIngredientes.de(const [
        IngredienteRotulo(nome: 'Chocolate Negro 50% METRO Chef', gramas: 10, nomeRotulo: 'Chocolate negro'),
        IngredienteRotulo(nome: 'Ovo liquido', gramas: 5, nomeRotulo: 'Ovos frescos'),
      ]).resumida();
      expect(r.textoSimples, 'Chocolate negro, Ovos frescos');
    });

    test('marca acrescenta-se na completa se faltar no nome', () {
      final r = ListaIngredientes.de(const [
        IngredienteRotulo(nome: 'Manteiga', gramas: 10, marca: 'Président'),
      ]);
      expect(r.textoSimples, 'Manteiga Président');
    });

    test('nomeCurtoAuto', () {
      expect(nomeCurtoAuto('Chocolate Branco 30% Chocovic', marca: 'Chocovic'), 'Chocolate Branco');
      expect(nomeCurtoAuto('Framboesa Congelada'), 'Framboesa');
      expect(nomeCurtoAuto('Ovo liquido'), 'Ovos');
      expect(nomeCurtoAuto('Sal Grosso Iodado'), 'Sal Grosso');
      expect(nomeCurtoAuto('Farinha de trigo T55'), 'Farinha de trigo');
      expect(nomeCurtoAuto('Raspas de Limão'), 'Limão');
      expect(nomeCurtoAuto('Congelado'), 'Congelado');
    });
  });

  group('pendenciasProduto', () {
    test('ficha vazia: falta tudo', () {
      const f = FichaTecnica(id: '1', nome: 'Boston');
      expect(pendenciasProduto(f), [
        'Sem informação nutricional',
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
      // a descrição é opcional: nunca conta como falta
      expect(pendenciasProduto(const FichaTecnica(id: '2', nome: 'X')).any((e) => e.contains('descrição')), isFalse);
      expect(p.contains('Sem prazo de validade'), isFalse);
      expect(p.contains('Sem modo de conservação'), isFalse);
    });
  });
}
