import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/sales/domain/produto_nao_identificado.dart';
import 'package:gc_turnkey/src/features/sales/domain/venda.dart';

VendaItem _item({
  String? fichaId,
  required String descricao,
  double quantidade = 1,
  double precoUnitario = 1,
}) =>
    VendaItem(
      id: 'x',
      vendaId: 'v',
      fichaId: fichaId,
      descricao: descricao,
      quantidade: quantidade,
      precoUnitario: precoUnitario,
      totalLinha: quantidade * precoUnitario,
    );

void main() {
  test('ignora linhas já com ficha', () {
    final r = agruparSemFicha([
      _item(fichaId: 'f1', descricao: 'Boston'),
      _item(descricao: 'Sem produto'),
    ]);
    expect(r, hasLength(1));
    expect(r.single.descricao, 'Sem produto');
  });

  test('agrupa por descrição exata, somando linhas/quantidade/total', () {
    final r = agruparSemFicha([
      _item(descricao: 'Gookie Belém do Pará', quantidade: 1, precoUnitario: 5),
      _item(descricao: 'Gookie Belém do Pará', quantidade: 2, precoUnitario: 5),
      _item(descricao: 'Outro produto', quantidade: 1, precoUnitario: 3),
    ]);
    expect(r, hasLength(2));
    final belem = r.firstWhere((p) => p.descricao == 'Gookie Belém do Pará');
    expect(belem.linhas, 2);
    expect(belem.quantidade, 3);
    expect(belem.total, 15);
  });

  test('ordenado por total, decrescente', () {
    final r = agruparSemFicha([
      _item(descricao: 'A', precoUnitario: 1),
      _item(descricao: 'B', precoUnitario: 10),
      _item(descricao: 'C', precoUnitario: 5),
    ]);
    expect(r.map((p) => p.descricao).toList(), ['B', 'C', 'A']);
  });

  test('lista vazia sem itens sem ficha', () {
    expect(agruparSemFicha([_item(fichaId: 'f1', descricao: 'X')]), isEmpty);
    expect(agruparSemFicha(const []), isEmpty);
  });
}
