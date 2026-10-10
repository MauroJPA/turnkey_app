import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/finance/domain/iva.dart';
import 'package:gc_turnkey/src/features/finance/domain/tabela_revendedor.dart';
import 'package:gc_turnkey/src/features/pricing/domain/cost_config.dart';
import 'package:gc_turnkey/src/features/products/domain/produto_rotulo.dart';
import 'package:gc_turnkey/src/features/sales/domain/venda.dart';
import 'package:gc_turnkey/src/features/tech_sheets/domain/tech_sheet.dart';
import 'package:gc_turnkey/src/features/tech_sheets/domain/tech_sheet_item.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  test('fromRecord lê a revenda e o IVA próprio (só com iva_proprio)', () {
    final r = RecordModel({
      'id': 'f',
      'nome': 'Coca-Cola lata',
      'revenda': true,
      'iva_proprio': true,
      'iva_pct': 23,
    });
    final f = FichaTecnica.fromRecord(r);
    expect(f.revenda, isTrue);
    expect(f.ivaProduto, 23);
    expect(f.ivaPara(13), 23);

    final semIva = FichaTecnica.fromRecord(
      RecordModel({'id': 'g', 'nome': 'Água', 'iva_pct': 6}),
    );
    expect(semIva.revenda, isFalse);
    expect(semIva.ivaProduto, isNull); // sem iva_proprio, vale o da empresa
    expect(semIva.ivaPara(13), 13);
    // copyWith e igualdade mantêm os campos novos
    expect(f.copyWith(nome: 'x').ivaProduto, 23);
    expect(f == f.copyWith(), isTrue);
    expect(f == f.copyWith(ivaProduto: 6), isFalse);
  });

  test('a revenda só pede a nutrição (o rótulo é o do próprio produto)', () {
    const ficha = FichaTecnica(id: 'a', nome: 'Cookie');
    const bebida = FichaTecnica(id: 'b', nome: 'Água', revenda: true);
    expect(pendenciasProduto(ficha), contains('Sem prazo de validade'));
    expect(pendenciasProduto(bebida), isNot(contains('Sem prazo de validade')));
    expect(
      pendenciasProduto(bebida),
      isNot(contains('Sem modo de conservação')),
    );
    expect(pendenciasProduto(bebida), contains('Sem informação nutricional'));
  });

  test('IVA estimado usa a taxa de cada produto', () {
    final v = Venda(id: 'v', data: DateTime(2026, 10, 1));
    final linhas = linhasDeIva(
      vendas: [v],
      itens: const [
        VendaItem(id: '1', vendaId: 'v', fichaId: 'coca', totalLinha: 123),
        VendaItem(id: '2', vendaId: 'v', fichaId: 'cookie', totalLinha: 113),
      ],
      taxaPadraoPercent: 13,
      taxaPorFicha: const {'coca': 23},
    );
    expect(linhas[0].iva, closeTo(23, 1e-9));
    expect(linhas[1].iva, closeTo(13, 1e-9));
  });

  test('tabela de revendedores: cada produto com o seu IVA', () {
    const config = CostConfig(ivaVendas: 13);
    final t = calcularTabela(
      fichas: const [
        FichaTecnica(id: 'c', nome: 'Coca', precoVenda: 2.46, ivaProduto: 23),
        FichaTecnica(id: 'k', nome: 'Cookie', precoVenda: 2.26),
      ],
      config: config,
    );
    final coca = t.firstWhere((l) => l.ficha.id == 'c');
    final cookie = t.firstWhere((l) => l.ficha.id == 'k');
    expect(coca.precoSemIva, closeTo(2.0, 0.005));
    expect(coca.precoComIva, closeTo(2.46, 0.005));
    expect(cookie.precoSemIva, closeTo(2.0, 0.005));
  });

  test('linha da ficha mostra a unidade do artigo (1 un, 33 ml)', () {
    const un = ItemFicha(
      id: 'i',
      fichaId: 'f',
      slot: SlotFicha.extra,
      quantidadeG: 1,
      unidade: 'un',
    );
    expect(un.quantidadeTexto, '1 un');
    expect(un.copyWith(quantidadeG: 1.5).quantidadeTexto, '1.5 un');
    const g = ItemFicha(
      id: 'j',
      fichaId: 'f',
      slot: SlotFicha.massa,
      quantidadeG: 80,
    );
    expect(g.quantidadeTexto, '80 g');
  });
}
