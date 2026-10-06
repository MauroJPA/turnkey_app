import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/production/domain/plano_pronto.dart';

String _eur(double v) => '€${v.toStringAsFixed(2).replaceAll('.', ',')}';

ResumoPlanoPronto _base({int produtos = 3, int semReceita = 0}) =>
    ResumoPlanoPronto(
      rotulo: 'amanhã',
      produtos: produtos,
      semReceita: semReceita,
    );

void main() {
  group('linhaProducao', () {
    test('plural e singular', () {
      expect(_base().linhaProducao, '3 produtos para amanhã');
      expect(_base(produtos: 1).linhaProducao, '1 produto para amanhã');
    });

    test('avisa dos que ficaram de fora', () {
      expect(
        _base(semReceita: 2).linhaProducao,
        '3 produtos para amanhã · 2 sem receita ligada ficou de fora',
      );
    });
  });

  group('compras', () {
    test('por omissão ainda não estão preparadas', () {
      final r = _base();
      expect(r.compras, EstadoCompras.naoPreparadas);
      expect(r.comprasEmDia, isFalse);
      expect(r.linhaCompras(_eur), 'A lista de compras não foi preparada.');
    });

    test('faltam ingredientes: contagem, custo e nomes', () {
      final r = _base().comCompras(
        compras: EstadoCompras.faltam,
        aComprar: 4,
        custo: 23.4,
        nomes: ['Manteiga', 'Farinha', 'Açúcar', 'Chocolate', 'Ovos', 'Sal'],
      );
      expect(r.linhaCompras(_eur), 'Faltam 4 ingredientes (≈ €23,40)');
      expect(
        r.nomesResumidos(),
        'Manteiga · Farinha · Açúcar · Chocolate e mais 2',
      );
      expect(r.comprasEmDia, isFalse);
    });

    test('um só ingrediente, sem custo conhecido', () {
      final r = _base().comCompras(
        compras: EstadoCompras.faltam,
        aComprar: 1,
        nomes: ['Manteiga'],
      );
      expect(r.linhaCompras(_eur), 'Falta 1 ingrediente');
      expect(r.nomesResumidos(), 'Manteiga');
    });

    test('o stock chega: está em dia', () {
      final r = _base().comCompras(compras: EstadoCompras.chega);
      expect(r.comprasEmDia, isTrue);
      expect(r.linhaCompras(_eur), 'O stock chega: não falta comprar nada.');
    });

    test('erro e vazia', () {
      expect(
        _base().comCompras(compras: EstadoCompras.erro).linhaCompras(_eur),
        'Não consegui preparar a lista de compras.',
      );
      final v = _base().comCompras(compras: EstadoCompras.vazia);
      expect(v.comprasEmDia, isTrue);
    });

    test('comCompras mantém o resto', () {
      final r = _base(semReceita: 1).comCompras(compras: EstadoCompras.chega);
      expect(r.rotulo, 'amanhã');
      expect(r.produtos, 3);
      expect(r.semReceita, 1);
    });
  });
}
