import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/daily_count/domain/contagem_dia.dart';
import 'package:gc_turnkey/src/features/daily_count/domain/local.dart';
import 'package:gc_turnkey/src/features/daily_count/domain/movimento_produto.dart';
import 'package:gc_turnkey/src/features/sales/domain/venda.dart';

void main() {
  const loja = Local(
    id: 'loja',
    nome: 'Loja',
    canais: ['Loja física'],
    ordem: 1,
  );
  const alv = Local(
    id: 'alv',
    nome: 'Alvalade',
    tipo: TipoLocal.parceiro,
    canais: ['Parceria Alvalade'],
    ordem: 2,
  );
  const plat = Local(
    id: 'plat',
    nome: 'Plataformas',
    tipo: TipoLocal.plataforma,
    canais: ['Uber Eats', 'Glovo'],
    ordem: 3,
  );
  const locais = [loja, alv, plat];

  MovimentoProduto mov(
    String tipo,
    String local,
    String ficha,
    double q, {
    DateTime? dia,
    String destino = '',
    MotivoDesperdicio? motivo,
  }) => MovimentoProduto(
    id: '${tipo}_${local}_${ficha}_$q',
    data: dia ?? DateTime(2026, 10, 3),
    localId: local,
    fichaId: ficha,
    tipo: TipoMovimento.values.firstWhere((t) => t.api == tipo),
    quantidade: q,
    destinoId: destino,
    motivo: motivo,
  );

  group('localDoCanal', () {
    test('canal conhecido → o seu local (sem distinguir maiúsculas)', () {
      expect(localDoCanal('Parceria Alvalade', locais)?.id, 'alv');
      expect(localDoCanal('  uber eats ', locais)?.id, 'plat');
    });

    test('canal vazio ou desconhecido → a loja', () {
      expect(localDoCanal('', locais)?.id, 'loja');
      expect(localDoCanal('Revenda', locais)?.id, 'loja');
    });

    test('locais arquivados são ignorados', () {
      const arquivada = Local(
        id: 'alv',
        nome: 'Alvalade',
        canais: ['Parceria Alvalade'],
        arquivado: true,
      );
      expect(localDoCanal('Parceria Alvalade', [loja, arquivada])?.id, 'loja');
      expect(localDoCanal('x', const <Local>[]), isNull);
    });

    test('sem loja, usa o primeiro local ativo', () {
      expect(localDoCanal('x', [alv, plat])?.id, 'alv');
    });
  });

  group('vendasPorLocal', () {
    test('reparte as linhas pelo canal da venda', () {
      final vendas = [
        Venda(id: 'v1', data: DateTime(2026, 10, 3), canal: 'Loja física'),
        Venda(id: 'v2', data: DateTime(2026, 10, 3), canal: 'Glovo'),
        Venda(id: 'v3', data: DateTime(2026, 10, 3)), // sem canal
      ];
      final itens = [
        const VendaItem(id: 'i1', vendaId: 'v1', fichaId: 'f1', quantidade: 3),
        const VendaItem(id: 'i2', vendaId: 'v2', fichaId: 'f1', quantidade: 2),
        const VendaItem(id: 'i3', vendaId: 'v3', fichaId: 'f2', quantidade: 1),
        // sem produto identificado: não conta para nenhum sabor
        const VendaItem(id: 'i4', vendaId: 'v1', quantidade: 5),
      ];
      final r = vendasPorLocal(vendas: vendas, itens: itens, locais: locais);
      expect(r, hasLength(3));
      expect(
        r
            .firstWhere((v) => v.fichaId == 'f1' && v.localId == 'loja')
            .quantidade,
        3,
      );
      expect(r.firstWhere((v) => v.localId == 'plat').quantidade, 2);
      expect(r.firstWhere((v) => v.fichaId == 'f2').localId, 'loja');
    });
  });

  group('calcularContagemDia', () {
    final dia = DateTime(2026, 10, 3);

    test('abertura = último fecho; esperado e diferença', () {
      final movs = [
        mov('contagem_fecho', 'loja', 'f1', 8, dia: DateTime(2026, 10, 2)),
        mov('producao', 'loja', 'f1', 20),
        mov('transferencia', 'alv', 'f1', 4, destino: 'loja'), // devolvido
        mov('transferencia', 'loja', 'f1', 6, destino: 'alv'), // enviado
        mov('desperdicio', 'loja', 'f1', 2, motivo: MotivoDesperdicio.queimado),
        mov('contagem_fecho', 'loja', 'f1', 9),
      ];
      final vendas = [
        VendaDoLocal(localId: 'loja', data: dia, fichaId: 'f1', quantidade: 12),
      ];
      final l = calcularContagemDia(
        localId: 'loja',
        dia: dia,
        fichaIds: ['f1'],
        movimentos: movs,
        vendas: vendas,
      ).single;
      expect(l.abertura, 8);
      expect(l.aberturaContada, isFalse);
      expect(l.assados, 20);
      expect(l.recebido, 4);
      expect(l.enviado, 6);
      expect(l.vendido, 12);
      expect(l.desperdicio, 2);
      // 8 + 20 + 4 - 6 - 12 - 2 = 12
      expect(l.esperado, 12);
      expect(l.fecho, 9);
      expect(l.diferenca, -3); // faltam 3 sem explicação
    });

    test('contagem de abertura manda e mostra a diferença da noite', () {
      final movs = [
        mov('contagem_fecho', 'loja', 'f1', 8, dia: DateTime(2026, 10, 2)),
        mov('contagem_abertura', 'loja', 'f1', 7),
      ];
      final l = calcularContagemDia(
        localId: 'loja',
        dia: dia,
        fichaIds: ['f1'],
        movimentos: movs,
        vendas: const [],
      ).single;
      expect(l.abertura, 7);
      expect(l.aberturaContada, isTrue);
      expect(l.diferencaAbertura, -1);
    });

    test(
      'sem contagens anteriores a abertura é 0 e sem fecho não há diferença',
      () {
        final l = calcularContagemDia(
          localId: 'loja',
          dia: dia,
          fichaIds: ['f1'],
          movimentos: [mov('producao', 'loja', 'f1', 10)],
          vendas: const [],
        ).single;
        expect(l.abertura, 0);
        expect(l.esperado, 10);
        expect(l.fecho, isNull);
        expect(l.diferenca, isNull);
      },
    );

    test('Alvalade recebe o que a loja envia e conta o seu fecho', () {
      final movs = [
        mov('transferencia', 'loja', 'f1', 10, destino: 'alv'),
        mov('contagem_fecho', 'alv', 'f1', 3),
      ];
      final vendas = [
        VendaDoLocal(localId: 'alv', data: dia, fichaId: 'f1', quantidade: 6),
      ];
      final l = calcularContagemDia(
        localId: 'alv',
        dia: dia,
        fichaIds: ['f1'],
        movimentos: movs,
        vendas: vendas,
      ).single;
      expect(l.recebido, 10);
      expect(l.vendido, 6);
      expect(l.esperado, 4);
      expect(l.diferenca, -1);
    });

    test('sem fecho contado, a abertura vem do que devia ter ficado ontem', () {
      final ontem = DateTime(2026, 10, 2);
      final movs = [
        mov('producao', 'loja', 'f1', 24, dia: ontem),
        mov(
          'desperdicio',
          'loja',
          'f1',
          2,
          dia: ontem,
          motivo: MotivoDesperdicio.queimado,
        ),
        mov(
          'desperdicio',
          'loja',
          'f1',
          1,
          dia: ontem,
          motivo: MotivoDesperdicio.consumoProprio,
        ),
      ];
      final vendas = [
        VendaDoLocal(
          localId: 'loja',
          data: ontem,
          fichaId: 'f1',
          quantidade: 15,
        ),
      ];
      final l = calcularContagemDia(
        localId: 'loja',
        dia: dia,
        fichaIds: ['f1'],
        movimentos: movs,
        vendas: vendas,
      ).single;
      // 24 assados - 15 vendidos - 3 perdas = 6
      expect(l.abertura, 6);
      expect(l.fechoAnterior, 6);
      expect(l.fechoAnteriorEstimado, isTrue);
      expect(l.aberturaContada, isFalse);
    });

    test('a estimativa continua dia após dia até haver uma contagem', () {
      final movs = [
        mov('contagem_fecho', 'loja', 'f1', 10, dia: DateTime(2026, 9, 30)),
        mov('producao', 'loja', 'f1', 20, dia: DateTime(2026, 10, 1)),
        mov('producao', 'loja', 'f1', 10, dia: DateTime(2026, 10, 2)),
      ];
      final vendas = [
        VendaDoLocal(
          localId: 'loja',
          data: DateTime(2026, 10, 1),
          fichaId: 'f1',
          quantidade: 25,
        ),
        VendaDoLocal(
          localId: 'loja',
          data: DateTime(2026, 10, 2),
          fichaId: 'f1',
          quantidade: 8,
        ),
      ];
      final l = calcularContagemDia(
        localId: 'loja',
        dia: dia,
        fichaIds: ['f1'],
        movimentos: movs,
        vendas: vendas,
      ).single;
      // 10 +20 -25 = 5 ; 5 +10 -8 = 7
      expect(l.abertura, 7);
      expect(l.fechoAnteriorEstimado, isTrue);
    });

    test('um fecho contado ganha à estimativa', () {
      final movs = [
        mov('producao', 'loja', 'f1', 24, dia: DateTime(2026, 10, 2)),
        mov('contagem_fecho', 'loja', 'f1', 5, dia: DateTime(2026, 10, 2)),
      ];
      final l = calcularContagemDia(
        localId: 'loja',
        dia: dia,
        fichaIds: ['f1'],
        movimentos: movs,
        vendas: const [],
      ).single;
      expect(l.abertura, 5);
      expect(l.fechoAnteriorEstimado, isFalse);
    });

    test('a estimativa nunca fica negativa', () {
      final movs = [
        mov('producao', 'loja', 'f1', 5, dia: DateTime(2026, 10, 2)),
      ];
      final vendas = [
        VendaDoLocal(
          localId: 'loja',
          data: DateTime(2026, 10, 2),
          fichaId: 'f1',
          quantidade: 9,
        ),
      ];
      final l = calcularContagemDia(
        localId: 'loja',
        dia: dia,
        fichaIds: ['f1'],
        movimentos: movs,
        vendas: vendas,
      ).single;
      expect(l.abertura, 0);
    });

    test('só conta o dia pedido', () {
      final movs = [
        mov('producao', 'loja', 'f1', 5, dia: DateTime(2026, 10, 2)),
        mov('producao', 'loja', 'f1', 7),
      ];
      final l = calcularContagemDia(
        localId: 'loja',
        dia: dia,
        fichaIds: ['f1'],
        movimentos: movs,
        vendas: [
          VendaDoLocal(
            localId: 'loja',
            data: DateTime(2026, 10, 2),
            fichaId: 'f1',
            quantidade: 3,
          ),
        ],
      ).single;
      expect(l.assados, 7);
      expect(l.vendido, 0);
    });
  });

  group('relatórios', () {
    test('resumoDesperdicio: totais, motivos, custo e % dos assados', () {
      final r = resumoDesperdicio(
        movimentos: [
          mov('producao', 'loja', 'f1', 100),
          mov(
            'desperdicio',
            'loja',
            'f1',
            4,
            motivo: MotivoDesperdicio.queimado,
          ),
          mov(
            'desperdicio',
            'alv',
            'f2',
            6,
            motivo: MotivoDesperdicio.foraPrazo,
          ),
          mov('desperdicio', 'loja', 'f2', 1),
        ],
        custoPorFicha: {'f1': 1.0, 'f2': 2.0},
      );
      expect(r.unidades, 11);
      expect(r.custo, 4 * 1.0 + 7 * 2.0);
      expect(r.assados, 100);
      expect(r.percentDosAssados, 11);
      expect(r.porMotivo[MotivoDesperdicio.queimado], 4);
      expect(r.porMotivo[MotivoDesperdicio.foraPrazo], 6);
      expect(r.porMotivo[null], 1);
      expect(r.porSabor['f2'], 7);
      expect(r.porLocal['alv'], 6);
    });

    test('resumoDesperdicio: custo por motivo, sabor e local; evitável', () {
      final r = resumoDesperdicio(
        movimentos: [
          mov(
            'desperdicio',
            'loja',
            'f1',
            4,
            motivo: MotivoDesperdicio.queimado,
          ),
          mov(
            'desperdicio',
            'alv',
            'f2',
            6,
            motivo: MotivoDesperdicio.foraPrazo,
          ),
          mov(
            'desperdicio',
            'loja',
            'f2',
            2,
            motivo: MotivoDesperdicio.degustacao,
          ),
          mov('desperdicio', 'loja', 'f1', 1),
        ],
        custoPorFicha: {'f1': 1.0, 'f2': 2.0},
      );
      expect(r.custo, 4 * 1.0 + 8 * 2.0 + 1 * 1.0);
      expect(r.custoPorMotivo[MotivoDesperdicio.queimado], 4.0);
      expect(r.custoPorMotivo[MotivoDesperdicio.foraPrazo], 12.0);
      expect(r.custoPorMotivo[MotivoDesperdicio.degustacao], 4.0);
      expect(r.custoPorMotivo[null], 1.0);
      expect(r.custoPorSabor['f2'], 16.0);
      expect(r.custoPorLocal['alv'], 12.0);
      // evitável = queimado + fora de prazo; degustação é escolha; sem motivo não conta
      expect(r.custoEvitavel, 16.0);
      expect(r.custoOferta, 4.0);
      expect(r.maiorPerdaEvitavel, MotivoDesperdicio.foraPrazo);
    });

    test('sem desperdício evitável não há "maior perda"', () {
      final r = resumoDesperdicio(
        movimentos: [
          mov(
            'desperdicio',
            'loja',
            'f1',
            3,
            motivo: MotivoDesperdicio.consumoProprio,
          ),
        ],
        custoPorFicha: {'f1': 1.0},
      );
      expect(r.maiorPerdaEvitavel, isNull);
      expect(r.custoEvitavel, 0);
      expect(r.custoOferta, 3.0);
    });

    test('motivos evitáveis têm dica; os de escolha não', () {
      expect(MotivoDesperdicio.queimado.evitavel, isTrue);
      expect(MotivoDesperdicio.queimado.dica, isNotNull);
      expect(MotivoDesperdicio.degustacao.evitavel, isFalse);
      expect(MotivoDesperdicio.degustacao.dica, isNull);
      expect(MotivoDesperdicio.outro.evitavel, isFalse);
    });

    test('balancoDoLocal: quantos foram para Alvalade e quantos voltaram', () {
      final b = balancoDoLocal(
        localId: 'alv',
        movimentos: [
          mov('transferencia', 'loja', 'f1', 30, destino: 'alv'),
          mov(
            'transferencia',
            'loja',
            'f1',
            10,
            destino: 'alv',
            dia: DateTime(2026, 10, 4),
          ),
          mov('transferencia', 'alv', 'f1', 5, destino: 'loja'),
          mov(
            'desperdicio',
            'alv',
            'f1',
            2,
            motivo: MotivoDesperdicio.foraPrazo,
          ),
          mov('transferencia', 'loja', 'f2', 8, destino: 'alv'),
          // não é de Alvalade
          mov('producao', 'loja', 'f3', 99),
        ],
        vendas: [
          VendaDoLocal(
            localId: 'alv',
            data: DateTime(2026, 10, 3),
            fichaId: 'f1',
            quantidade: 20,
          ),
        ],
      );
      expect(b.map((x) => x.fichaId).toSet(), {'f1', 'f2'});
      final f1 = b.firstWhere((x) => x.fichaId == 'f1');
      expect(f1.recebido, 40);
      expect(f1.enviado, 5); // voltaram
      expect(f1.vendido, 20);
      expect(f1.desperdicio, 2);
      expect(f1.saldo, 40 - 5 - 20 - 2);
      expect(b.first.fichaId, 'f1'); // ordenado por recebidos
    });
  });
}
