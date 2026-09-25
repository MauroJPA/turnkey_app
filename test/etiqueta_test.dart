import 'package:flutter_test/flutter_test.dart';
import 'package:turnkey_app/src/core/nutrition/nutrition.dart';
import 'package:turnkey_app/src/features/products/domain/etiqueta.dart';
import 'package:turnkey_app/src/features/products/domain/lista_ingredientes.dart';

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
    String produtor = 'Gookie Cookies, Lda\nRua X, Porto',
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
    test('tem tamanho 50x80, frente 25 e corpo 55 mm', () {
      final h = etiquetaPagina(dados());
      expect(h, contains('size: 50mm 80mm'));
      expect(h, contains('.topo { height: 25mm'));
      expect(h, contains('.corpo { height: 55mm'));
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
      expect(h, contains('Gookie Cookies, Lda<br>Rua X, Porto'));
      expect(h, contains('<b>Pode conter:</b> Frutos de casca rija.'));
      expect(h, contains('referência, aproximados'));
    });

    test('altura da parte de baixo configurável', () {
      final d = EtiquetaDados(nome: 'X', fabrico: DateTime(2026, 1, 1), alturaCorpoMm: 75);
      final h = etiquetaPagina(d);
      expect(h, contains('size: 50mm 100mm'));
      expect(h, contains('.corpo { height: 75mm'));
    });

    test('largura e altura da frente configuráveis', () {
      final d = EtiquetaDados(
        nome: 'X',
        fabrico: DateTime(2026, 1, 1),
        larguraMm: 60,
        alturaFrenteMm: 30,
        alturaCorpoMm: 70,
      );
      final h = etiquetaPagina(d);
      expect(h, contains('size: 60mm 100mm'));
      expect(h, contains('.etq { width: 60mm; height: 100mm'));
      expect(h, contains('.topo { height: 30mm'));
      expect(h, contains('.corpo { height: 70mm'));
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
      final h = etiquetaPagina(EtiquetaDados(
        nome: 'X',
        fabrico: DateTime(2026, 9, 24),
        validadeDias: 7,
        imprimirDatas: false,
      ));
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
        larguraMm: 60,
        alturaFrenteMm: 30,
        alturaCorpoMm: 75,
      );
      final r = EtiquetaPrefs.fromJson(p.toJson());
      expect(r.resumida, isTrue);
      expect(r.modoNutri, EtiquetaNutri.linear);
      expect(r.tipoData, EtiquetaData.ate);
      expect(r.imprimirDatas, isFalse);
      expect(r.mostrarE, isTrue);
      expect((r.larguraMm, r.alturaFrenteMm, r.alturaCorpoMm), (60, 30, 75));
    });

    test('vazio, inválido ou fora de limites → predefinidos seguros', () {
      for (final raw in [null, '', 5, <String, Object>{}]) {
        final r = EtiquetaPrefs.fromJson(raw);
        expect(r.resumida, isFalse);
        expect(r.modoNutri, EtiquetaNutri.tabela);
        expect(r.imprimirDatas, isTrue);
        expect(r.mostrarE, isFalse);
        expect((r.larguraMm, r.alturaFrenteMm, r.alturaCorpoMm), (50, 25, 55));
      }
      final r = EtiquetaPrefs.fromJson({
        'modoNutri': 'xpto',
        'larguraMm': 5,
        'alturaCorpoMm': 9999,
      });
      expect(r.modoNutri, EtiquetaNutri.tabela);
      expect(r.larguraMm, 30);
      expect(r.alturaCorpoMm, 150);
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
