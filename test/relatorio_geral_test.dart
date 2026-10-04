import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/daily_count/domain/local.dart';
import 'package:gc_turnkey/src/features/daily_count/domain/movimento_produto.dart';
import 'package:gc_turnkey/src/features/finance/domain/custo_fixo.dart';
import 'package:gc_turnkey/src/features/finance/domain/equipamento.dart';
import 'package:gc_turnkey/src/features/finance/domain/relatorio_exportar.dart';
import 'package:gc_turnkey/src/features/finance/domain/relatorio_geral.dart';
import 'package:gc_turnkey/src/features/ingredients/domain/ingredient.dart';
import 'package:gc_turnkey/src/features/invoices/domain/fatura.dart';
import 'package:gc_turnkey/src/features/sales/domain/venda.dart';
import 'package:gc_turnkey/src/features/schedule/domain/production_plan.dart';
import 'package:gc_turnkey/src/features/tech_sheets/domain/tech_sheet.dart';

void main() {
  final desde = DateTime(2026, 9, 1);
  final ate = DateTime(2026, 10, 2);

  EntradaRelatorio entrada({double? iva}) => EntradaRelatorio(
    empresa: 'Gookie',
    desde: desde,
    ate: ate,
    geradoEm: DateTime(2026, 10, 2),
    ivaAssumidoPercent: iva,
    vendas: [
      Venda(
        id: 'v1',
        data: DateTime(2026, 9, 10),
        origem: OrigemVenda.vendus,
        canal: 'Loja física',
        hora: '14:33',
        metodoPagamento: 'MB Way',
        numeroDocumento: 'FT 1',
      ),
      Venda(id: 'v2', data: DateTime(2026, 10, 1), origem: OrigemVenda.csv),
      // fora do período
      Venda(id: 'v3', data: DateTime(2026, 8, 1)),
    ],
    itens: [
      const VendaItem(
        id: 'i1',
        vendaId: 'v1',
        fichaId: 'f1',
        descricao: 'Kinder',
        quantidade: 2,
        precoUnitario: 5.30,
        totalLinha: 10.60,
        custoUnitarioSnapshot: 1.2,
        valorSemIva: 10,
        ivaPercent: 6,
      ),
      const VendaItem(
        id: 'i2',
        vendaId: 'v2',
        descricao: 'Coisa estranha',
        quantidade: 1,
        precoUnitario: 6.15,
        totalLinha: 6.15,
      ),
      const VendaItem(
        id: 'i3',
        vendaId: 'v3',
        fichaId: 'f1',
        quantidade: 1,
        precoUnitario: 1,
        totalLinha: 1,
      ),
    ],
    fichas: const [
      FichaTecnica(
        id: 'f1',
        nome: 'Boston',
        subnome: 'Red Velvet',
        custoProduto: 1.5,
        pesoProduto: 150,
        precoVenda: 5.3,
      ),
    ],
    componentes: const [
      ComponenteSabor(
        fichaId: 'f1',
        componente: 'Massa',
        item: 'Massa Boston',
        tipo: 'receita',
        quantidade: 120,
        unidade: 'g',
        custoUnitario: 0.01,
        custoLinha: 1.2,
      ),
      ComponenteSabor(
        fichaId: 'f1',
        componente: 'Embalagem',
        item: 'Saco',
        tipo: 'embalagem',
        quantidade: 1,
        unidade: 'peças',
        custoUnitario: 0.3,
        custoLinha: 0.3,
        eEmbalagem: true,
      ),
    ],
    ingredientesDosSabores: const [
      IngredienteDoSabor(
        fichaId: 'f1',
        ingredienteId: 'g1',
        nome: 'Farinha',
        quantidade: 60,
        unidade: 'g',
      ),
    ],
    ingredientes: const [
      Ingrediente(
        id: 'g1',
        nome: 'Farinha',
        marca: 'Sidul',
        preco: 1.5,
        gramasEmbalagem: 1000,
      ),
    ],
    custosFixos: const [
      CustoFixo(id: 'c1', nome: 'Renda da loja', valorMensal: 600),
      CustoFixo(
        id: 'c2',
        nome: 'Instagram Ads',
        tipo: TipoCusto.variavel,
        valorMensal: 80,
        diaPagamento: 15,
      ),
    ],
    equipamentos: const [
      Equipamento(id: 'q1', nome: 'Forno', custo: 1200, vidaUtilAnos: 10),
    ],
    faturas: [
      Fatura(
        id: 'ft1',
        tipo: FaturaTipo.fatura,
        estado: FaturaEstado.confirmada,
        fornecedor: 'Makro',
        numero: 'A/1',
        dataFatura: '2026-09-05',
        total: 123,
        iva: 23,
        dadosIa: const {
          'linhas': [
            {
              'descricao': 'Farinha T55',
              'nome_generico': 'Farinha',
              'quantidade': 25,
              'unidade': 'kg',
              'preco_unitario': 0.9,
              'total': 75,
            },
            {
              'descricao': 'Saco kraft',
              'tipo_item': 'embalagem',
              'quantidade': 100,
              'unidade': 'un',
              'preco_unitario': 0.25,
              'total': 25,
            },
          ],
        },
      ),
      // não conta: não confirmada
      const Fatura(
        id: 'ft2',
        tipo: FaturaTipo.fatura,
        estado: FaturaEstado.analisada,
        dataFatura: '2026-09-06',
        total: 999,
      ),
    ],
    locais: const [
      Local(id: 'loja', nome: 'Loja', canais: ['Loja física'], ordem: 1),
      Local(
        id: 'alv',
        nome: 'Alvalade',
        tipo: TipoLocal.parceiro,
        canais: ['Parceria Alvalade'],
        ordem: 2,
      ),
    ],
    movimentosProduto: [
      MovimentoProduto(
        id: 'm1',
        data: DateTime(2026, 9, 9),
        localId: 'loja',
        fichaId: 'f1',
        tipo: TipoMovimento.contagemFecho,
        quantidade: 4,
      ),
      MovimentoProduto(
        id: 'm2',
        data: DateTime(2026, 9, 10),
        localId: 'loja',
        fichaId: 'f1',
        tipo: TipoMovimento.producao,
        quantidade: 20,
      ),
      MovimentoProduto(
        id: 'm3',
        data: DateTime(2026, 9, 10),
        localId: 'loja',
        fichaId: 'f1',
        tipo: TipoMovimento.transferencia,
        quantidade: 6,
        destinoId: 'alv',
      ),
      MovimentoProduto(
        id: 'm4',
        data: DateTime(2026, 9, 10),
        localId: 'loja',
        fichaId: 'f1',
        tipo: TipoMovimento.desperdicio,
        quantidade: 2,
        motivo: MotivoDesperdicio.queimado,
      ),
      MovimentoProduto(
        id: 'm5',
        data: DateTime(2026, 9, 10),
        localId: 'loja',
        fichaId: 'f1',
        tipo: TipoMovimento.contagemFecho,
        quantidade: 12,
      ),
    ],
    producoes: [
      ProducaoPlan(
        id: 'p1',
        data: DateTime(2026, 9, 10),
        titulo: 'x',
        estado: EstadoProducao.concluida,
      ),
    ],
    itensProducao: const [
      ItemProducaoRelatorio(
        producaoId: 'p1',
        item: ProducaoItem(
          id: 'pi1',
          receitaId: 'r1',
          nome: 'Massa Boston',
          quantidadeKg: 3,
          fichaId: 'f1',
          fichaNome: 'Boston',
          unidadesPrevistas: 20,
        ),
      ),
    ],
  );

  FolhaRelatorio folha(List<FolhaRelatorio> fs, String nome) =>
      fs.firstWhere((f) => f.nome == nome);

  group('montarRelatorio', () {
    test('tem todas as folhas da especificação', () {
      final fs = montarRelatorio(entrada());
      expect(
        fs.map((f) => f.nome),
        containsAll([
          'Leia-me',
          'Resumo mensal',
          '1 Vendas',
          '1 Equivalencia nomes',
          '2 Producao',
          '2 Contagem diaria',
          '3 Custo por sabor',
          '3 Componentes',
          '3 Ingredientes',
          '3 Historico precos',
          '4 Despesas',
          '5 Plataformas',
          '6 Pessoal',
          '7 Tesouraria',
          '8 Eventos',
          '9 Origem clientes',
        ]),
      );
    });

    test('vendas: só o período, canal, hora e IVA registado', () {
      final v = folha(montarRelatorio(entrada()), '1 Vendas');
      expect(v.linhas, hasLength(2));
      final cols = v.colunas;
      Object? c(int linha, String col) => v.linhas[linha][cols.indexOf(col)];
      expect(c(0, 'data'), '2026-09-10');
      expect(c(0, 'hora'), '14:33');
      expect(c(0, 'canal'), 'Loja física');
      expect(c(0, 'sabor'), 'Boston');
      expect(c(0, 'descricao_original'), 'Kinder');
      expect(c(0, 'valor_liquido_sem_iva'), 10);
      expect(c(0, 'iva_origem'), 'registado');
      expect(c(0, 'valor_com_iva'), 10.6);
      expect(c(0, 'metodo_pagamento'), 'MB Way');
      expect(c(1, 'canal'), 'Não indicado');
      expect(c(1, 'sabor'), '(produto não identificado)');
      expect(c(1, 'valor_liquido_sem_iva'), isNull);
      expect(c(1, 'iva_origem'), 'desconhecido');
    });

    test('IVA assumido estima o valor sem IVA só onde não está registado', () {
      final v = folha(montarRelatorio(entrada(iva: 23)), '1 Vendas');
      final cols = v.colunas;
      Object? c(int linha, String col) => v.linhas[linha][cols.indexOf(col)];
      expect(c(0, 'valor_liquido_sem_iva'), 10); // registado, não é tocado
      expect(c(1, 'valor_liquido_sem_iva'), 5); // 6.15 / 1.23
      expect(c(1, 'iva_origem'), 'estimado (23 %)');
    });

    test('despesas: fatura repartida por categoria + custos + depreciação', () {
      final d = folha(montarRelatorio(entrada()), '4 Despesas');
      final cols = d.colunas;
      Object? c(List<Object?> l, String col) => l[cols.indexOf(col)];
      final fatura = d.linhas.where((l) => c(l, 'fonte') == 'fatura').toList();
      expect(fatura, hasLength(2)); // ingredientes + embalagem
      final ing = fatura.firstWhere((l) => c(l, 'categoria') == 'ingredientes');
      final emb = fatura.firstWhere((l) => c(l, 'categoria') == 'embalagem');
      // 75 / 100 = 75 % do total de 123 (100 sem IVA)
      expect(c(ing, 'valor_com_iva'), 92.25);
      expect(c(ing, 'valor_sem_iva'), 75);
      expect(c(emb, 'valor_com_iva'), 30.75);
      expect(c(emb, 'valor_sem_iva'), 25);
      // custos registados: 2 meses (set + out) x 2 custos
      final custos = d.linhas
          .where((l) => c(l, 'fonte') == 'custo mensal registado')
          .toList();
      expect(custos, hasLength(4));
      expect(custos.any((l) => c(l, 'categoria') == 'renda'), isTrue);
      expect(custos.any((l) => c(l, 'categoria') == 'marketing'), isTrue);
      expect(
        custos.firstWhere((l) => c(l, 'descricao') == 'Instagram Ads')[0],
        '2026-09-15',
      );
      expect(
        d.linhas.where((l) => c(l, 'fonte') == 'depreciação'),
        hasLength(2),
      );
      // a fatura não confirmada não conta
      expect(d.linhas.any((l) => c(l, 'valor_com_iva') == 999), isFalse);
    });

    test('resumo mensal: valores de setembro (compras e CMV não se somam)', () {
      final r = folha(montarRelatorio(entrada(iva: 23)), 'Resumo mensal');
      final cols = r.colunas;
      final set = r.linhas.firstWhere((l) => l[0] == '2026-09');
      Object? c(String col) => set[cols.indexOf(col)];
      expect(c('n_vendas'), 1);
      expect(c('vendas_com_iva'), 10.6);
      expect(c('vendas_sem_iva'), 10);
      expect(c('custo_materia_prima_vendida'), 2.4);
      expect(c('margem_bruta_sem_iva'), 7.6);
      expect(c('despesas_fixas'), 600); // renda
      expect(c('despesas_variaveis'), 80); // anúncios
      expect(c('depreciacao_equipamentos'), 10); // 1200 / (10 x 12)
      expect(c('compras_ingredientes_e_embalagem'), 100);
      // 7.6 - 600 - 80 - 10
      expect(c('resultado_estimado'), -682.4);
      // IVA: 10,60 - 10 = 0,60 cobrado; a fatura de 123 tem 23 de IVA
      expect(c('iva_cobrado_nas_vendas'), 0.6);
      expect(c('iva_das_compras'), 23);
      expect(c('iva_a_entregar'), -22.4);
    });

    test('resumo mensal sem IVA completo deixa o resultado em branco', () {
      final r = folha(montarRelatorio(entrada()), 'Resumo mensal');
      final cols = r.colunas;
      final out = r.linhas.firstWhere((l) => l[0] == '2026-10');
      expect(out[cols.indexOf('vendas_sem_iva')], isNull);
      expect(out[cols.indexOf('resultado_estimado')], isNull);
    });

    test('custo por sabor separa a embalagem e calcula a margem', () {
      final c = folha(montarRelatorio(entrada(iva: 23)), '3 Custo por sabor');
      final cols = c.colunas;
      final l = c.linhas.single;
      Object? v(String col) => l[cols.indexOf(col)];
      expect(v('sabor'), 'Boston');
      expect(v('custo_embalagem_por_unidade'), 0.3);
      expect(v('custo_ingredientes_por_unidade'), 1.2);
      expect(v('custo_total_por_unidade'), 1.5);
      expect(v('preco_venda_sem_iva'), 4.31); // 5.3 / 1.23
      expect(v('margem_eur_por_unidade'), 2.81);
    });

    test('ingredientes por sabor trazem o preço e o custo na unidade', () {
      final i = folha(montarRelatorio(entrada()), '3 Ingredientes');
      final cols = i.colunas;
      final l = i.linhas.single;
      expect(l[cols.indexOf('marca')], 'Sidul');
      expect(l[cols.indexOf('custo_por_g_ou_ml')], 0.0015);
      expect(l[cols.indexOf('custo_na_unidade_de_produto')], 0.09);
    });

    test('histórico de preços vem das faturas confirmadas', () {
      final h = folha(montarRelatorio(entrada()), '3 Historico precos');
      expect(h.linhas, hasLength(2));
      expect(h.linhas.first[0], '2026-09-05');
    });

    test('produção cruza com as vendas do dia', () {
      final p = folha(montarRelatorio(entrada()), '2 Producao');
      final cols = p.colunas;
      final l = p.linhas.single;
      expect(l[cols.indexOf('sabor')], 'Boston');
      expect(l[cols.indexOf('tipo_de_linha')], 'produto final');
      expect(l[cols.indexOf('unidades_produzidas')], 20);
      expect(l[cols.indexOf('unidades_vendidas_no_dia')], 2);
      expect(l[cols.indexOf('sobras')], isNull);
    });

    test(
      'equivalência de nomes junta a descrição da venda ao sabor oficial',
      () {
        final e = folha(montarRelatorio(entrada()), '1 Equivalencia nomes');
        expect(e.colunas, [
          'descricao_na_venda',
          'sabor_oficial',
          'linhas',
          'unidades',
        ]);
        final kinder = e.linhas.firstWhere((l) => l[0] == 'Kinder');
        expect(kinder[1], 'Boston');
        expect(kinder[3], 2);
        final estranha = e.linhas.firstWhere((l) => l[0] == 'Coisa estranha');
        expect(estranha[1], '(produto não identificado)');
      },
    );

    test(
      'contagem diária: assados, envios, desperdício e sobras por dia/local',
      () {
        final c = folha(montarRelatorio(entrada()), '2 Contagem diaria');
        final cols = c.colunas;
        Object? v(List<Object?> l, String col) => l[cols.indexOf(col)];
        final loja = c.linhas.firstWhere(
          (l) => v(l, 'local') == 'Loja' && v(l, 'data') == '2026-09-10',
        );
        expect(v(loja, 'sabor'), 'Boston');
        expect(v(loja, 'abertura'), 4); // herdada do fecho de 09/09
        expect(v(loja, 'assados'), 20);
        expect(v(loja, 'enviados'), 6);
        expect(v(loja, 'vendidos'), 2); // venda v1 (Loja física) nesse dia
        expect(v(loja, 'desperdicio'), 2);
        expect(v(loja, 'desperdicio_motivo'), 'Queimado 2');
        expect(v(loja, 'devia_haver'), 4 + 20 - 6 - 2 - 2);
        expect(v(loja, 'sobras_contadas'), 12);
        expect(v(loja, 'diferenca_contado_menos_esperado'), 12 - 14);
        // o mesmo envio aparece em Alvalade como recebido
        final alv = c.linhas.firstWhere((l) => v(l, 'local') == 'Alvalade');
        expect(v(alv, 'recebidos'), 6);
        // dias sem registos não aparecem
        expect(
          c.linhas.map((l) => v(l, 'data')).toSet(),
          {'2026-09-09', '2026-09-10'},
        );
      },
    );

    test('folhas por preencher têm só os cabeçalhos', () {
      final fs = montarRelatorio(entrada());
      for (final n in [
        '5 Plataformas',
        '6 Pessoal',
        '8 Eventos',
        '9 Origem clientes',
      ]) {
        expect(folha(fs, n).linhas, isEmpty, reason: n);
        expect(folha(fs, n).colunas, isNotEmpty, reason: n);
      }
    });
  });

  group('categoriaDeCusto', () {
    test('palavras-chave', () {
      expect(categoriaDeCusto('Renda da loja'), 'renda');
      expect(categoriaDeCusto('Aluguel'), 'renda');
      expect(categoriaDeCusto('EDP eletricidade'), 'eletricidade e água');
      expect(categoriaDeCusto('Internet NOS'), 'internet e telefone');
      expect(categoriaDeCusto('Contabilista'), 'contabilidade');
      expect(categoriaDeCusto('Seguro multirriscos'), 'seguros');
      expect(categoriaDeCusto('Anúncios Instagram'), 'marketing');
      expect(categoriaDeCusto('Subscrição Canva'), 'software e subscrições');
      expect(categoriaDeCusto('Salário Ana'), 'pessoal');
      expect(categoriaDeCusto('Coisa qualquer'), 'outras');
    });
  });

  group('exportação', () {
    final folhas = montarRelatorio(entrada(iva: 23));

    test('xlsx: um zip válido com uma folha por relatório', () {
      final bytes = relatorioXlsx(folhas);
      final arq = ZipDecoder().decodeBytes(bytes);
      final nomes = arq.files.map((f) => f.name).toSet();
      expect(
        nomes,
        containsAll([
          '[Content_Types].xml',
          'xl/workbook.xml',
          'xl/styles.xml',
        ]),
      );
      for (var i = 1; i <= folhas.length; i++) {
        expect(nomes, contains('xl/worksheets/sheet$i.xml'));
      }
      String texto(String n) => utf8.decode(
        arq.files.firstWhere((f) => f.name == n).content as List<int>,
      );
      final wb = texto('xl/workbook.xml');
      expect(wb, contains('<sheet name="1 Vendas"'));
      expect(wb, contains('<sheet name="Leia-me"'));
      final idx = folhas.indexWhere((f) => f.nome == '1 Vendas') + 1;
      final s = texto('xl/worksheets/sheet$idx.xml');
      expect(s, contains('<c r="A1" s="1" t="inlineStr">'));
      expect(s, contains('Kinder'));
      expect(s, contains('<c r="E2"><v>2.0</v></c>')); // quantidade (double)
      // XML bem formado: tags abertas e fechadas em igual número (sanidade)
      expect('<row '.allMatches(s).length, '</row>'.allMatches(s).length);
    });

    test('xlsx escapa texto e tira caracteres inválidos', () {
      final bytes = relatorioXlsx([
        const FolhaRelatorio(
          nome: 'a/b:c*[x]',
          colunas: ['c'],
          linhas: [
            ['<&>"\u0001ok'],
          ],
        ),
      ]);
      final arq = ZipDecoder().decodeBytes(bytes);
      final wb = utf8.decode(
        arq.files.firstWhere((f) => f.name == 'xl/workbook.xml').content
            as List<int>,
      );
      expect(wb, contains('name="a b c  x"'));
      final s = utf8.decode(
        arq.files
                .firstWhere((f) => f.name == 'xl/worksheets/sheet1.xml')
                .content
            as List<int>,
      );
      expect(s, contains('&lt;&amp;&gt;&quot;ok'));
      expect(s, isNot(contains('\u0001')));
    });

    test('csv zip: um ficheiro por folha, UTF-8, vírgulas e aspas', () {
      final bytes = relatorioCsvZip([
        const FolhaRelatorio(
          nome: '1 Vendas',
          colunas: ['sabor', 'valor', 'ok'],
          linhas: [
            ['Boston, "Red"', 4.5, true],
            ['Café', null, false],
          ],
        ),
      ]);
      final arq = ZipDecoder().decodeBytes(bytes);
      expect(arq.files.single.name, '01-1-vendas.csv');
      final csv = utf8.decode(arq.files.single.content as List<int>);
      expect(csv, contains('sabor,valor,ok'));
      expect(csv, contains('"Boston, ""Red""",4.5,sim'));
      expect(csv, contains('Café,,não'));
    });
  });
}
