import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/finance/domain/analise_vendas.dart';
import 'package:gc_turnkey/src/features/finance/domain/periodo.dart';
import 'package:gc_turnkey/src/features/sales/domain/venda.dart';

VendaItem _item({
  String? ficha,
  double quantidade = 1,
  double totalLinha = 0,
  double custo = 0,
}) =>
    VendaItem(
      id: 'i',
      vendaId: 'v',
      fichaId: ficha,
      quantidade: quantidade,
      totalLinha: totalLinha,
      custoUnitarioSnapshot: custo,
    );

void main() {
  group('agruparPorFicha', () {
    test('agrupa por ficha, soma quantidade/receita/custo', () {
      final itens = [
        _item(ficha: 'f1', quantidade: 2, totalLinha: 7, custo: 1.5),
        _item(ficha: 'f1', quantidade: 3, totalLinha: 10.5, custo: 1.5),
      ];
      final r = agruparPorFicha(itens, {'f1': 'Cookie Chocolate'});
      expect(r, hasLength(1));
      expect(r.first.nome, 'Cookie Chocolate');
      expect(r.first.quantidade, 5);
      expect(r.first.receita, closeTo(17.5, 0.001));
      expect(r.first.custo, closeTo(2 * 1.5 + 3 * 1.5, 0.001));
    });

    test('linhas sem ficha ficam sob "Sem produto identificado", sem custo',
        () {
      final itens = [_item(quantidade: 1, totalLinha: 20)];
      final r = agruparPorFicha(itens, {});
      expect(r.first.fichaId, '');
      expect(r.first.temFicha, isFalse);
      expect(r.first.nome, 'Sem produto identificado');
      expect(r.first.custo, 0);
    });

    test('ficha sem nome resolvido (apagada) aparece como "Ficha removida"',
        () {
      final itens = [_item(ficha: 'fx', quantidade: 1, totalLinha: 5)];
      final r = agruparPorFicha(itens, {});
      expect(r.first.nome, 'Ficha removida');
    });

    test('ordenado por receita, decrescente', () {
      final itens = [
        _item(ficha: 'a', totalLinha: 10),
        _item(ficha: 'b', totalLinha: 50),
        _item(ficha: 'c', totalLinha: 30),
      ];
      final r = agruparPorFicha(itens, {'a': 'A', 'b': 'B', 'c': 'C'});
      expect(r.map((v) => v.nome), ['B', 'C', 'A']);
    });
  });

  group('VendaPorFicha', () {
    test('margemPercent = (receita-custo)/receita*100, 0 se receita 0', () {
      const v = VendaPorFicha(
          fichaId: 'a', nome: 'A', quantidade: 1, receita: 100, custo: 30);
      expect(v.margemPercent, closeTo(70, 0.001));
      const semReceita = VendaPorFicha(
          fichaId: 'a', nome: 'A', quantidade: 1, receita: 0, custo: 0);
      expect(semReceita.margemPercent, 0);
    });
  });

  group('quantidadePorFicha', () {
    test('soma quantidade por fichaId, agrupando sem-ficha em ""', () {
      final itens = [
        _item(ficha: 'a', quantidade: 2),
        _item(ficha: 'a', quantidade: 3),
        _item(quantidade: 1),
      ];
      final r = quantidadePorFicha(itens);
      expect(r['a'], 5);
      expect(r[''], 1);
    });
  });

  group('AnaliseVendas.tendenciaPercent', () {
    test('null quando não há dados anteriores dessa ficha', () {
      const v = VendaPorFicha(
          fichaId: 'a', nome: 'A', quantidade: 10, receita: 0, custo: 0);
      final a = AnaliseVendas(
        periodo: _periodoDummy(),
        porFicha: const [v],
        quantidadeAnterior: const {},
      );
      expect(a.tendenciaPercent(v), isNull);
    });

    test('variação percentual da quantidade face ao período anterior', () {
      const v = VendaPorFicha(
          fichaId: 'a', nome: 'A', quantidade: 15, receita: 0, custo: 0);
      final a = AnaliseVendas(
        periodo: _periodoDummy(),
        porFicha: const [v],
        quantidadeAnterior: const {'a': 10},
      );
      expect(a.tendenciaPercent(v), closeTo(50, 0.001));
    });
  });
}

Periodo _periodoDummy() => Periodo(
      desde: DateTime(2026, 1, 1),
      ate: DateTime(2026, 1, 7),
      label: 'x',
    );
