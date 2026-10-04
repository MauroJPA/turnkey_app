import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/haccp/domain/haccp.dart';
import 'package:gc_turnkey/src/features/haccp/domain/haccp_relatorio.dart';

void main() {
  const frigo = ControloHaccp(
    id: 'frigo',
    nome: 'Frigorífico <1>',
    tipo: TipoControlo.temperatura,
    periodicidadeDias: 1,
    vezesPorDia: 2,
    limiteMin: 0,
    limiteMax: 5,
    local: 'Cozinha',
  );
  const limpeza = ControloHaccp(
    id: 'limp',
    nome: 'Limpeza semanal',
    tipo: TipoControlo.limpeza,
    periodicidadeDias: 7,
  );
  const ocasional = ControloHaccp(id: 'oc', nome: 'Lote', periodicidadeDias: 0);

  RegistoHaccp reg(
    String id,
    String controlo,
    DateTime quando, {
    double? valor,
    bool conforme = true,
    bool resolvido = false,
    String responsavel = 'Ana',
    String acao = '',
    String notas = '',
  }) => RegistoHaccp(
    id: id,
    controloId: controlo,
    dataHora: quando,
    valor: valor,
    conforme: conforme,
    resolvido: resolvido,
    responsavel: responsavel,
    acaoCorretiva: acao,
    notas: notas,
  );

  final desde = DateTime(2026, 10, 1);
  final ate = DateTime(2026, 10, 7); // 7 dias

  group('esperadosNoPeriodo', () {
    test('diário: dias × vezes por dia', () {
      expect(esperadosNoPeriodo(frigo, desde, ate), 14);
      expect(esperadosNoPeriodo(frigo, desde, desde), 2);
    });
    test('semanal: um por semana completa; ocasional: nenhum', () {
      expect(esperadosNoPeriodo(limpeza, desde, ate), 1);
      expect(esperadosNoPeriodo(limpeza, desde, DateTime(2026, 10, 31)), 4);
      expect(esperadosNoPeriodo(limpeza, desde, DateTime(2026, 10, 3)), 0);
      expect(esperadosNoPeriodo(ocasional, desde, ate), 0);
    });
  });

  group('integridadeHaccp', () {
    final a = reg('1', 'frigo', DateTime.utc(2026, 10, 2, 8), valor: 3);
    final b = reg('2', 'frigo', DateTime.utc(2026, 10, 2, 18), valor: 4);

    test('é estável e não depende da ordem', () {
      expect(integridadeHaccp([a, b]), integridadeHaccp([b, a]));
      expect(integridadeHaccp([a, b]), hasLength(16));
      expect(integridadeHaccp([a, b]), matches(RegExp(r'^[0-9A-F]{16}$')));
    });
    test('muda se um valor, uma ação ou um registo mudar', () {
      final base = integridadeHaccp([a, b]);
      expect(
        integridadeHaccp([
          a,
          reg('2', 'frigo', DateTime.utc(2026, 10, 2, 18), valor: 4.5),
        ]),
        isNot(base),
      );
      expect(
        integridadeHaccp([
          a,
          reg(
            '2',
            'frigo',
            DateTime.utc(2026, 10, 2, 18),
            valor: 4,
            conforme: false,
          ),
        ]),
        isNot(base),
      );
      expect(integridadeHaccp([a]), isNot(base));
      expect(integridadeHaccp(const []), integridadeHaccp(const []));
    });
  });

  RelatorioHaccp relatorio({
    TipoControlo? tipo,
    List<RegistoHaccp>? registos,
    String operador = 'Gookie Lda\nRua X, Lisboa',
  }) => RelatorioHaccp(
    codigo: 'HACCP-2026-0007',
    empresa: 'Gookie',
    operador: operador,
    desde: desde,
    ate: ate,
    tipo: tipo,
    controlos: const [frigo, limpeza, ocasional],
    registos:
        registos ??
        [
          reg('1', 'frigo', DateTime(2026, 10, 2, 8, 5), valor: 3.5),
          reg(
            '2',
            'frigo',
            DateTime(2026, 10, 2, 18),
            valor: 8,
            conforme: false,
            acao: 'Porta mal fechada <fechei>',
          ),
          reg('3', 'limp', DateTime(2026, 10, 3, 20), notas: 'Tudo limpo'),
        ],
    emitidoEm: DateTime(2026, 10, 8, 9, 30),
    emitidoPor: 'Mauro',
  );

  group('haccpRelatorioLegalHtml', () {
    test(
      'cabeçalho: número, período, operador, emitido por, enquadramento',
      () {
        final h = haccpRelatorioLegalHtml(relatorio());
        expect(h, contains('HACCP-2026-0007'));
        expect(h, contains('01/10/2026 a 07/10/2026'));
        expect(h, contains('Gookie Lda<br>Rua X, Lisboa'));
        expect(h, contains('Mauro'));
        expect(h, contains('Regulamento (CE) n.º 852/2004'));
        expect(h, contains('Regulamento (CE) n.º 178/2002'));
        expect(h, contains('Decreto-Lei n.º 113/2006'));
        expect(h, contains('Verificado pelo responsável HACCP'));
        expect(h, contains(relatorio().integridade));
      },
    );

    test('um quadro por controlo, com limites, valores e não conformidade', () {
      final h = haccpRelatorioLegalHtml(relatorio());
      expect(h, contains('1. Controlo de temperaturas'));
      expect(h, contains('2. Higienização e limpeza'));
      expect(h, contains('Limite crítico: <b>0 a 5 °C</b>'));
      expect(h, contains('3,5 °C'));
      expect(h, contains('class="nc"'));
      expect(h, contains('Mínimo 3,5 °C'));
      expect(h, contains('Máximo 8 °C'));
      // não conformidades, com a ação corretiva
      expect(h, contains('Não conformidades e ações corretivas'));
      expect(h, contains('8 °C (limite 0 a 5 °C)'));
      expect(h, contains('Por resolver'));
    });

    test('escapa o texto vindo dos utilizadores', () {
      final h = haccpRelatorioLegalHtml(relatorio());
      expect(h, contains('Frigorífico &lt;1&gt;'));
      expect(h, contains('Porta mal fechada &lt;fechei&gt;'));
      expect(h, isNot(contains('<fechei>')));
    });

    test('cobertura: registos feitos face aos esperados', () {
      final h = haccpRelatorioLegalHtml(relatorio());
      // frigo 2 de 14 + limpeza 1 de 1 = 3 de 15
      expect(h, contains('3 de 15 esperados'));
      expect(h, contains('20%'));
      expect(h, contains('Registos: 2 de 14 esperados'));
    });

    test('só o tipo pedido entra', () {
      final h = haccpRelatorioLegalHtml(
        relatorio(
          tipo: TipoControlo.limpeza,
          registos: [reg('3', 'limp', DateTime(2026, 10, 3, 20))],
        ),
      );
      expect(h, contains('Higienização e limpeza'));
      expect(h, isNot(contains('Controlo de temperaturas')));
      expect(h, contains('Não houve não conformidades no período.'));
    });

    test('sem registos diz-se e usa o nome da empresa sem operador', () {
      final h = haccpRelatorioLegalHtml(
        relatorio(registos: const [], operador: ''),
      );
      expect(h, contains('Sem registos neste período.'));
      expect(h, contains('Gookie'));
    });
  });

  test('o estilo põe o número do documento e as páginas no rodapé', () {
    final e = haccpRelatorioEstilo('HACCP-2026-0007');
    expect(e, contains('HACCP-2026-0007'));
    expect(e, contains('counter(page)'));
  });
}
