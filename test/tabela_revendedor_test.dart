import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/finance/domain/tabela_revendedor.dart';
import 'package:gc_turnkey/src/features/pricing/domain/canal_venda.dart';
import 'package:gc_turnkey/src/features/pricing/domain/cost_config.dart';
import 'package:gc_turnkey/src/features/tech_sheets/domain/tech_sheet.dart';

void main() {
  const cfg = CostConfig(cmv: 30, ivaVendas: 23);

  FichaTecnica ficha(String nome, double venda, {String cat = ''}) =>
      FichaTecnica(
        id: nome,
        nome: nome,
        categoria: cat,
        custoProduto: 1,
        precoVenda: venda,
      );

  String fmt(double v) => '${v.toStringAsFixed(2).replaceAll('.', ',')} €';

  test('lerEscalas: ordena, tira repetidos e ignora lixo', () {
    expect(lerEscalas('48:10; 24:5;24:7;x:1;1:5;10:150;12'), const [
      EscalaDesconto(24, 7),
      EscalaDesconto(48, 10),
    ]);
    expect(lerEscalas(null), isEmpty);
    expect(lerEscalas(escreverEscalas(const [EscalaDesconto(24, 5.5)])), const [
      EscalaDesconto(24, 5.5),
    ]);
  });

  test('desconto sobre o preço público (sem IVA) e depois o IVA', () {
    // 6,15 com IVA = 5,00 sem IVA; −30 % = 3,50; com IVA 4,31 (3,50×1,23=4,305)
    final l = calcularTabela(
      fichas: [ficha('Alba', 6.15)],
      config: cfg,
      descontoPct: 30,
    ).single;
    expect(l.precoSemIva, 3.5);
    expect(l.precoComIva, closeTo(4.31, 1e-9));
  });

  test('escalas de volume descontam sobre o preço de revenda', () {
    final l = calcularTabela(
      fichas: [ficha('Alba', 6.15)],
      config: cfg,
      descontoPct: 30,
      escalas: const [EscalaDesconto(24, 5), EscalaDesconto(48, 10)],
    ).single;
    expect(l.escalas, [3.33, 3.15]); // 3,325→3,33 · 3,15
  });

  test('com canal: o preço é o que chega depois das taxas', () {
    const canal = CanalVenda(
      id: 'c',
      nome: 'Revendedor',
      taxas: [TaxaCanal(nome: 'Revendedor', percent: 40)],
    );
    final l = calcularTabela(
      fichas: [ficha('Alba', 6.15)],
      config: cfg,
      canal: canal,
      descontoPct: 5, // ignorado quando há canal
    ).single;
    expect(l.precoSemIva, 3.0);
  });

  test('só entram produtos com preço, sem apagados nem excluídos', () {
    final l = calcularTabela(
      fichas: [
        ficha('A', 6.15),
        ficha('B', 0),
        ficha('C', 6.15).copyWith(deletado: true),
        ficha('D', 6.15),
      ],
      config: cfg,
      excluidos: {'D'},
    );
    expect(l.map((x) => x.ficha.nome), ['A']);
  });

  test('ordena por categoria e nome', () {
    final l = calcularTabela(
      fichas: [
        ficha('Z', 6.15, cat: 'Bolachas'),
        ficha('A', 6.15, cat: 'Tartes'),
        ficha('B', 6.15, cat: 'Bolachas'),
      ],
      config: cfg,
    );
    expect(l.map((x) => x.ficha.nome), ['B', 'Z', 'A']);
  });

  test('texto de WhatsApp e HTML (com escape) trazem preços e degraus', () {
    final linhas = calcularTabela(
      fichas: [ficha('Alba <b>', 6.15, cat: 'Bolachas')],
      config: cfg,
      descontoPct: 30,
      escalas: const [EscalaDesconto(24, 5)],
    );
    final data = DateTime(2026, 10, 6);
    final txt = tabelaTexto(
      linhas: linhas,
      escalas: const [EscalaDesconto(24, 5)],
      ivaPct: 23,
      empresa: 'Gookie',
      fmt: fmt,
      data: data,
    );
    expect(txt, contains('*Gookie*'));
    expect(txt, contains('06/10/2026'));
    expect(txt, contains('3,50 € (4,31 € c/IVA)'));
    expect(txt, contains('24+ unidades: −5 %'));

    final html = tabelaHtml(
      linhas: linhas,
      escalas: const [EscalaDesconto(24, 5)],
      ivaPct: 23,
      empresa: 'Gookie <script>',
      fmt: fmt,
      data: data,
    );
    expect(html, isNot(contains('<script>')));
    expect(html, contains('Alba &lt;b&gt;'));
    expect(html, contains('24+ un'));
    expect(html, contains('Preço c/IVA'));
  });

  test('sem IVA definido não há coluna nem texto de IVA', () {
    final linhas = calcularTabela(
      fichas: [ficha('Alba', 5)],
      config: const CostConfig(),
    );
    final txt = tabelaTexto(
      linhas: linhas,
      escalas: const [],
      ivaPct: 0,
      empresa: '',
      fmt: fmt,
      data: DateTime(2026, 1, 2),
    );
    expect(txt, isNot(contains('IVA')));
    expect(
      tabelaHtml(
        linhas: linhas,
        escalas: const [],
        ivaPct: 0,
        empresa: '',
        fmt: fmt,
        data: DateTime(2026, 1, 2),
      ),
      isNot(contains('c/IVA')),
    );
  });
}
