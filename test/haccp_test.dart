import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/haccp/domain/haccp.dart';

void main() {
  final agora = DateTime(2026, 10, 4, 15, 0); // domingo

  RegistoHaccp reg(
    String controlo,
    DateTime quando, {
    bool conforme = true,
    bool resolvido = false,
    DateTime? proximo,
    double? valor,
  }) => RegistoHaccp(
    id: '${controlo}_${quando.millisecondsSinceEpoch}',
    controloId: controlo,
    dataHora: quando,
    conforme: conforme,
    resolvido: resolvido,
    proximoVencimento: proximo,
    valor: valor,
  );

  const frigo = ControloHaccp(
    id: 'frigo',
    nome: 'Frigorífico',
    tipo: TipoControlo.temperatura,
    periodicidadeDias: 1,
    vezesPorDia: 2,
    limiteMin: 0,
    limiteMax: 5,
  );
  const limpeza = ControloHaccp(
    id: 'limp',
    nome: 'Limpeza semanal',
    tipo: TipoControlo.limpeza,
    periodicidadeDias: 7,
  );
  const extintor = ControloHaccp(
    id: 'ext',
    nome: 'Extintor',
    tipo: TipoControlo.manutencao,
    periodicidadeDias: 365,
  );

  group('limites e texto', () {
    test('valorConforme respeita mínimo e máximo', () {
      expect(frigo.valorConforme(3), isTrue);
      expect(frigo.valorConforme(0), isTrue);
      expect(frigo.valorConforme(5), isTrue);
      expect(frigo.valorConforme(5.1), isFalse);
      expect(frigo.valorConforme(-1), isFalse);
      const congelador = ControloHaccp(
        id: 'c',
        nome: 'Arca',
        tipo: TipoControlo.temperatura,
        limiteMax: -18,
      );
      expect(congelador.valorConforme(-20), isTrue);
      expect(congelador.valorConforme(-10), isFalse);
    });

    test('limitesTexto', () {
      expect(frigo.limitesTexto, '0 a 5 °C');
      expect(
        const ControloHaccp(
          id: 'c',
          nome: 'x',
          tipo: TipoControlo.temperatura,
          limiteMax: -18,
        ).limitesTexto,
        '≤ -18 °C',
      );
      expect(limpeza.limitesTexto, '');
    });

    test('periodicidadeTexto', () {
      expect(frigo.periodicidadeTexto, '2 vezes por dia');
      expect(limpeza.periodicidadeTexto, 'Todas as semanas');
      expect(extintor.periodicidadeTexto, 'Todos os anos');
      expect(
        const ControloHaccp(
          id: 'o',
          nome: 'o',
          periodicidadeDias: 0,
        ).periodicidadeTexto,
        'Ocasional',
      );
    });
  });

  group('estadoDoControlo', () {
    test('nunca registado → sem registo; ocasional → ocasional', () {
      expect(
        estadoDoControlo(frigo, const [], agora).estado,
        EstadoControlo.semRegisto,
      );
      expect(
        estadoDoControlo(
          const ControloHaccp(id: 'o', nome: 'o', periodicidadeDias: 0),
          const [],
          agora,
        ).estado,
        EstadoControlo.ocasional,
      );
    });

    test('diário com 2 vezes: 1 de 2 hoje → pendente; 2 de 2 → em dia', () {
      final um = [reg('frigo', DateTime(2026, 10, 4, 8))];
      final s1 = estadoDoControlo(frigo, um, agora);
      expect(s1.estado, EstadoControlo.pendenteHoje);
      expect(s1.feitosHoje, 1);
      expect(s1.esperadosHoje, 2);
      final dois = [...um, reg('frigo', DateTime(2026, 10, 4, 14))];
      expect(estadoDoControlo(frigo, dois, agora).estado, EstadoControlo.emDia);
    });

    test(
      'diário: último registo ontem → pendente hoje; há 3 dias → atrasado',
      () {
        expect(
          estadoDoControlo(frigo, [
            reg('frigo', DateTime(2026, 10, 3, 18)),
          ], agora).estado,
          EstadoControlo.pendenteHoje,
        );
        final s = estadoDoControlo(frigo, [
          reg('frigo', DateTime(2026, 10, 1, 18)),
        ], agora);
        expect(s.estado, EstadoControlo.atrasado);
        expect(s.diasAtraso, 2); // faltaram 2 e 3 de outubro
      },
    );

    test('semanal: em dia, vence hoje e atrasado', () {
      final emDia = estadoDoControlo(limpeza, [
        reg('limp', DateTime(2026, 10, 1, 10)),
      ], agora);
      expect(emDia.estado, EstadoControlo.emDia);
      expect(emDia.proximo, DateTime(2026, 10, 8));
      final hoje = estadoDoControlo(limpeza, [
        reg('limp', DateTime(2026, 9, 27, 10)),
      ], agora);
      expect(hoje.estado, EstadoControlo.pendenteHoje);
      final atrasado = estadoDoControlo(limpeza, [
        reg('limp', DateTime(2026, 9, 20, 10)),
      ], agora);
      expect(atrasado.estado, EstadoControlo.atrasado);
      expect(atrasado.diasAtraso, 7);
    });

    test('validade indicada no registo manda sobre a periodicidade', () {
      final r = reg(
        'ext',
        DateTime(2026, 1, 10),
        proximo: DateTime(2026, 9, 30),
      );
      final s = estadoDoControlo(extintor, [r], agora);
      expect(s.estado, EstadoControlo.atrasado);
      expect(s.diasAtraso, 4);
      expect(s.proximo, DateTime(2026, 9, 30));
      // sem validade, conta 365 dias desde o registo
      final s2 = estadoDoControlo(extintor, [
        reg('ext', DateTime(2026, 1, 10)),
      ], agora);
      expect(s2.estado, EstadoControlo.emDia);
      expect(s2.proximo, DateTime(2027, 1, 10));
    });

    test('ignora registos de outros controlos', () {
      final s = estadoDoControlo(limpeza, [
        reg('frigo', DateTime(2026, 10, 4, 8)),
      ], agora);
      expect(s.estado, EstadoControlo.semRegisto);
    });
  });

  group('estadoDosControlos', () {
    test('ordena os que pedem atenção primeiro e ignora arquivados', () {
      const arquivado = ControloHaccp(
        id: 'arq',
        nome: 'Velho',
        arquivado: true,
      );
      final r = estadoDosControlos(
        [limpeza, extintor, frigo, arquivado],
        [reg('limp', DateTime(2026, 10, 3)), reg('ext', DateTime(2026, 1, 1))],
        agora,
      );
      expect(r.map((x) => x.controlo.id), ['frigo', 'limp', 'ext']);
      expect(r.first.emAtraso, isTrue); // frigo: nunca registado
      expect(r.map((x) => x.controlo.id), isNot(contains('arq')));
    });
  });

  test('não conformidades abertas', () {
    final r = naoConformidadesAbertas([
      reg('frigo', DateTime(2026, 10, 1), conforme: false),
      reg('frigo', DateTime(2026, 10, 2), conforme: false, resolvido: true),
      reg('frigo', DateTime(2026, 10, 3)),
      reg('frigo', DateTime(2026, 10, 4), conforme: false),
    ]);
    expect(r, hasLength(2));
    expect(r.first.dataHora, DateTime(2026, 10, 4)); // a mais recente primeiro
  });

  test(
    'controlos habituais cobrem temperatura, limpeza, pragas, extintor e lote',
    () {
      final h = controlosHabituais();
      expect(h.map((c) => c.tipo).toSet(), {
        TipoControlo.temperatura,
        TipoControlo.limpeza,
        TipoControlo.praga,
        TipoControlo.manutencao,
        TipoControlo.outro, // registo de lote
      });
      final arca = h.firstWhere((c) => c.nome.contains('congeladora'));
      expect(arca.limiteMax, -18);
      expect(arca.limiteMin, isNull);
      final body = arca.toBody();
      expect(body['usa_limite_min'], isFalse);
      expect(body['usa_limite_max'], isTrue);
    },
  );

  group('relatório HTML', () {
    test('agrupa por controlo, mostra valor, e escapa texto', () {
      final html = haccpRelatorioHtml(
        empresa: 'Gookie <Lda>',
        periodo: '01/10/2026 – 31/10/2026',
        controlos: [frigo, limpeza],
        registos: [
          reg('frigo', DateTime(2026, 10, 2, 8, 5), valor: 3.5),
          RegistoHaccp(
            id: 'x',
            controloId: 'frigo',
            dataHora: DateTime(2026, 10, 2, 18),
            valor: 8,
            conforme: false,
            responsavel: 'Ana',
            acaoCorretiva: 'Verificar <portas>',
          ),
        ],
      );
      expect(html, contains('Gookie &lt;Lda&gt;'));
      expect(html, contains('<h2>Frigorífico</h2>'));
      expect(html, contains('3,5 °C'));
      expect(html, contains('8 °C'));
      expect(html, contains('class="nc"'));
      expect(html, contains('Verificar &lt;portas&gt;'));
      expect(html, contains('1 não conformidade(s) por resolver'));
      expect(html, isNot(contains('Limpeza semanal'))); // sem registos
    });

    test('sem registos diz-se', () {
      final html = haccpRelatorioHtml(
        empresa: 'X',
        periodo: 'p',
        controlos: [frigo],
        registos: const [],
      );
      expect(html, contains('Sem registos neste período.'));
    });
  });
}
