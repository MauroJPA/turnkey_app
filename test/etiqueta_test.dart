import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/core/nutrition/nutrition.dart';
import 'package:gc_turnkey/src/features/products/domain/etiqueta.dart';
import 'package:gc_turnkey/src/features/products/domain/lista_ingredientes.dart';

void main() {
  final lista = ListaIngredientes.de(const [
    IngredienteRotulo(
      nome: 'Farinha de trigo T55',
      gramas: 400,
      alergenios: ['Glúten'],
    ),
    IngredienteRotulo(nome: 'Manteiga', gramas: 250, alergenios: ['Leite']),
    IngredienteRotulo(nome: 'Framboesa Congelada', gramas: 80),
  ]);
  const nutri = Nutrientes(
    kcal: 394,
    lipidos: 20.5,
    saturados: 10,
    hidratos: 45,
    acucares: 22,
    fibra: 1.5,
    proteina: 5,
    sal: 0.4,
  );
  EtiquetaDados dados({
    bool resumida = false,
    EtiquetaNutri modo = EtiquetaNutri.tabela,
    bool e = false,
    int copias = 1,
    String produtor = 'Empresa Exemplo, Lda\nRua X, Porto',
    String nome = 'Boston',
  }) => EtiquetaDados(
    nome: nome,
    descricao: 'Cookie recheado',
    ingredientes: lista,
    resumida: resumida,
    nutri: nutri,
    modoNutri: modo,
    tracos: const ['Frutos de casca rija'],
    pesoLiquidoG: 150,
    mostrarE: e,
    conservacao: 'Local fresco e seco',
    fabrico: DateTime(2026, 9, 24),
    validadeDias: 7,
    lote: '260924',
    produtor: produtor,
    copias: copias,
  );

  group('etiquetaPagina', () {
    test('tem tamanho 50x80, frente 15 e corpo 65 mm', () {
      final h = etiquetaPagina(dados());
      expect(h, contains('size: 50mm 80mm'));
      expect(h, contains('.topo { height: 15mm'));
      expect(h, contains('.corpo { height: 65mm'));
    });

    test('subnome só aparece se for dado, por baixo do nome', () {
      expect(etiquetaPagina(dados()), isNot(contains('<p class="sub">')));
      final h = etiquetaPagina(
        EtiquetaDados(
          nome: 'Carolina do Sul',
          subnome: 'Red Velvet',
          descricao: 'Brigadeiro de queijo creme',
          fabrico: DateTime(2026, 1, 1),
        ),
      );
      expect(
        h,
        contains('<h1>Carolina do Sul</h1><p class="sub">Red Velvet</p>'),
      );
      expect(h.indexOf('<p class="sub">') < h.indexOf('<p class="desc">'), isTrue);
    });

    test('conteúdo legal: ingredientes, datas, peso, lote, produtor', () {
      final h = etiquetaPagina(dados());
      expect(
        h,
        contains('<b>Ingredientes:</b> Farinha de trigo T55 (<b>GLÚTEN</b>)'),
      );
      expect(h, contains('Peso líquido: 150 g</p>'));
      expect(h, isNot(contains('℮')));
      expect(h, contains('<b>Fabrico:</b> 24/09/2026'));
      expect(h, contains('Consumir de preferência antes de:</b> 01/10/2026'));
      expect(h, contains('<b>Lote:</b> 260924'));
      expect(h, contains('Empresa Exemplo, Lda<br>Rua X, Porto'));
      expect(h, contains('<b>Pode conter:</b> Frutos de casca rija.'));
      expect(h, contains('referência, aproximados'));
    });

    test('a parte de baixo é o que sobra do tamanho total', () {
      final d = EtiquetaDados(
        nome: 'X',
        fabrico: DateTime(2026, 1, 1),
        alturaTotalMm: 100,
      );
      final h = etiquetaPagina(d);
      expect(h, contains('size: 50mm 100mm'));
      expect(h, contains('.corpo { height: 85mm'));
    });

    test('largura, altura total e altura da frente', () {
      final d = EtiquetaDados(
        nome: 'X',
        fabrico: DateTime(2026, 1, 1),
        larguraMm: 60,
        alturaTotalMm: 100,
        alturaFrenteMm: 25,
      );
      final h = etiquetaPagina(d);
      expect(h, contains('size: 60mm 100mm'));
      expect(h, contains('.etq { width: 60mm; height: 100mm'));
      expect(h, contains('.topo { height: 25mm'));
      expect(h, contains('.corpo { height: 75mm'));
      expect(h, contains('60 × 100 mm'));
    });

    test('token de medição só envia mensagem se for dado', () {
      final d = EtiquetaDados(nome: 'X', fabrico: DateTime(2026, 1, 1));
      expect(etiquetaPagina(d), contains("if ('' && "));
      expect(etiquetaPagina(d, tokenMedicao: '123'), contains("if ('123' && "));
      expect(etiquetaPagina(d, tokenMedicao: '123'), contains("'etq:123:'"));
    });

    test('conservação com ponto final não duplica o ponto', () {
      final d = EtiquetaDados(
        nome: 'X',
        fabrico: DateTime(2026, 1, 1),
        conservacao: 'Local fresco e seco ou refrigerado. ',
      );
      final h = etiquetaPagina(d);
      expect(h, contains('Local fresco e seco ou refrigerado.</p>'));
      expect(h, isNot(contains('refrigerado..')));
    });

    test('datas em branco para escrever à caneta', () {
      final h = etiquetaPagina(
        EtiquetaDados(
          nome: 'X',
          fabrico: DateTime(2026, 9, 24),
          validadeDias: 7,
          imprimirDatas: false,
        ),
      );
      expect(h, contains('<b>Fabrico:</b> <span class="cx"></span>'));
      expect(h, isNot(contains('Consumir de preferência')));
      expect(h, contains('<b>Validade:</b> 7 dias após a data de fabrico'));
      expect(h, isNot(contains('24/09/2026')));
      expect(h, isNot(contains('01/10/2026')));
    });

    test('℮ só aparece se ligado', () {
      expect(etiquetaPagina(dados(e: true)), contains('150 g ℮'));
    });

    test('resumida usa nomes curtos', () {
      final h = etiquetaPagina(dados(resumida: true));
      expect(h, contains('Framboesa'));
      expect(h, isNot(contains('Framboesa Congelada')));
      expect(etiquetaPagina(dados()), contains('Framboesa Congelada'));
    });

    test('tabela vs linear vs nenhuma', () {
      expect(etiquetaPagina(dados()), contains('<table class="nutri">'));
      expect(etiquetaPagina(dados()), contains('394 kcal'));
      final l = etiquetaPagina(dados(modo: EtiquetaNutri.linear));
      expect(l, isNot(contains('<table class="nutri">')));
      expect(l, contains('Lípidos 20,5 g, dos quais saturados 10 g'));
      final n = etiquetaPagina(dados(modo: EtiquetaNutri.nenhuma));
      expect(n, isNot(contains('nutricionais médios')));
    });

    test('cópias: uma por página, só a primeira visível no ecrã', () {
      final h = etiquetaPagina(dados(copias: 3));
      expect('<div class="etq'.allMatches(h).length, 3);
      expect('etq rep'.allMatches(h).length, 2);
      expect(h, contains('Imprimir 3 etiquetas'));
    });

    test('escapa HTML', () {
      final h = etiquetaPagina(dados(nome: '<script>x</script>'));
      expect(h, isNot(contains('<script>x</script>')));
      expect(h, contains('&lt;script&gt;'));
    });
  });

  group('EtiquetaPrefs', () {
    test('vai e volta em JSON', () {
      const p = EtiquetaPrefs(
        resumida: true,
        modoNutri: EtiquetaNutri.linear,
        tipoData: EtiquetaData.ate,
        imprimirDatas: false,
        mostrarE: true,
        mostrarSubnome: true,
        larguraMm: 60,
        alturaTotalMm: 100,
        alturaFrenteMm: 22,
      );
      final r = EtiquetaPrefs.fromJson(p.toJson());
      expect(r.resumida, isTrue);
      expect(r.modoNutri, EtiquetaNutri.linear);
      expect(r.tipoData, EtiquetaData.ate);
      expect(r.imprimirDatas, isFalse);
      expect(r.mostrarE, isTrue);
      expect(r.mostrarSubnome, isTrue);
      expect((r.larguraMm, r.alturaTotalMm, r.alturaFrenteMm), (60, 100, 22));
    });

    test('vazio, inválido ou fora de limites → predefinidos seguros', () {
      for (final raw in [null, '', 5, <String, Object>{}]) {
        final r = EtiquetaPrefs.fromJson(raw);
        expect(r.resumida, isFalse);
        expect(r.modoNutri, EtiquetaNutri.tabela);
        expect(r.imprimirDatas, isTrue);
        expect(r.mostrarE, isFalse);
        expect(r.mostrarSubnome, isFalse);
        expect((r.larguraMm, r.alturaTotalMm, r.alturaFrenteMm), (50, 80, 15));
      }
      final r = EtiquetaPrefs.fromJson({
        'modoNutri': 'xpto',
        'larguraMm': 5,
        'alturaTotalMm': 9999,
        'alturaFrenteMm': 90,
      });
      expect(r.modoNutri, EtiquetaNutri.tabela);
      expect((r.larguraMm, r.alturaTotalMm), (50, 80));
      expect(r.alturaFrenteMm, 25);
    });

    test('a frente nunca fica abaixo de 15 mm', () {
      expect(EtiquetaPrefs.fromJson({'alturaFrenteMm': 3}).alturaFrenteMm, 15);
    });

    test('medidas antigas (frente + corpo livres) passam ao padrão', () {
      // 25 + 55 = 50 × 80
      final a = EtiquetaPrefs.fromJson({
        'larguraMm': 50,
        'alturaFrenteMm': 25,
        'alturaCorpoMm': 55,
      });
      expect((a.larguraMm, a.alturaTotalMm, a.alturaFrenteMm), (50, 80, 25));
      // 30 + 70 = 100 em 60 de largura
      final b = EtiquetaPrefs.fromJson({
        'larguraMm': 60,
        'alturaFrenteMm': 30,
        'alturaCorpoMm': 70,
      });
      expect((b.larguraMm, b.alturaTotalMm, b.alturaFrenteMm), (60, 100, 25));
      // 50 de largura, 25 + 65 = 90 → sobe para o 50 × 100
      final c = EtiquetaPrefs.fromJson({
        'larguraMm': 50,
        'alturaFrenteMm': 25,
        'alturaCorpoMm': 65,
      });
      expect(c.alturaTotalMm, 100);
    });
  });

  group('tamanhosEtiqueta', () {
    test('o primeiro é 50 × 80 e todos são padrão', () {
      expect(tamanhosEtiqueta.first, const TamanhoEtiqueta(50, 80));
      expect(tamanhoPadrao(50, 100), const TamanhoEtiqueta(50, 100));
      expect(tamanhoPadrao(33, 71), const TamanhoEtiqueta(50, 80));
      expect(tamanhoPadrao(50, 85), const TamanhoEtiqueta(50, 100));
    });
  });

  group('avisosEtiqueta', () {
    test(
      'completa: sem avisos',
      () => expect(avisosEtiqueta(dados()), isEmpty),
    );

    test('falta produtor, validade e conservação', () {
      final a = avisosEtiqueta(
        EtiquetaDados(nome: 'X', fabrico: DateTime(2026, 1, 1)),
      );
      expect(a, contains('Falta o nome e a morada do produtor'));
      expect(a.any((e) => e.contains('ingredientes')), isTrue);
      expect(a.any((e) => e.contains('validade')), isTrue);
      expect(a.any((e) => e.contains('conservação')), isTrue);
      expect(a.any((e) => e.contains('nutricionais')), isTrue);
    });
  });
}
