import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/daily_count/domain/fecho_dia.dart';

String _eur(double v) => '€${v.toStringAsFixed(2)}';

PassoFecho _passo(List<PassoFecho> ps, String chave) =>
    ps.firstWhere((p) => p.chave == chave);

void main() {
  test('sem acesso a nada não há passos', () {
    final ps = passosFecho(const DadosFecho(), dinheiro: _eur);
    expect(ps, isEmpty);
    expect(resumoFecho(ps), 'Nada para fechar');
  });

  test('um dia em ordem: tudo ok e o resumo diz que sim', () {
    final ps = passosFecho(
      const DadosFecho(
        semFechoPorLocal: {},
        comFecho: 6,
        desperdicioUn: 2,
        vendasN: 14,
        vendasTotal: 134.5,
        haccpPorFazer: 0,
        saidasPorMarcar: [],
        planoAmanha: true,
        porComprar: 0,
      ),
      dinheiro: _eur,
    );
    expect(ps.map((p) => p.chave), [
      'contagem',
      'desperdicio',
      'vendas',
      'haccp',
      'ponto',
      'amanha',
      'compras',
    ]);
    expect(ps.where((p) => p.estado == EstadoPasso.falta), isEmpty);
    expect(_passo(ps, 'contagem').texto, 'Fecho contado em 6 sabores');
    expect(_passo(ps, 'vendas').texto, '14 vendas · €134.50');
    expect(_passo(ps, 'desperdicio').texto, '2 un registadas hoje');
    expect(resumoFecho(ps), contains('Tudo em ordem'));
  });

  test('falta contar o fecho: diz onde e quantos', () {
    final ps = passosFecho(
      const DadosFecho(
        semFechoPorLocal: {'Loja': 3, 'Alvalade': 1},
        comFecho: 2,
      ),
      dinheiro: _eur,
    );
    final c = _passo(ps, 'contagem');
    expect(c.estado, EstadoPasso.falta);
    expect(c.texto, 'Falta o fecho de 4 sabores: Loja (3), Alvalade (1)');
    expect(resumoFecho(ps), 'Falta 1 coisa');
  });

  test('HACCP e saídas por marcar contam como falta', () {
    final ps = passosFecho(
      const DadosFecho(
        haccpPorFazer: 2,
        naoConformidades: 1,
        saidasPorMarcar: ['Ana', 'Rui'],
        aTrabalhar: ['Rita'],
      ),
      dinheiro: _eur,
    );
    expect(_passo(ps, 'haccp').estado, EstadoPasso.falta);
    expect(
      _passo(ps, 'haccp').texto,
      '2 controlos por fazer · 1 não conformidade',
    );
    expect(_passo(ps, 'ponto').estado, EstadoPasso.falta);
    expect(_passo(ps, 'ponto').texto, 'Falta marcar a saída: Ana, Rui');
    expect(resumoFecho(ps), 'Faltam 2 coisas');
  });

  test('quem ainda trabalha, sem vendas e sem plano: só informação', () {
    final ps = passosFecho(
      const DadosFecho(
        semFechoPorLocal: {},
        desperdicioUn: 0,
        vendasN: 0,
        saidasPorMarcar: [],
        aTrabalhar: ['Rita'],
        planoAmanha: false,
        porComprar: 5,
      ),
      dinheiro: _eur,
    );
    expect(_passo(ps, 'contagem').estado, EstadoPasso.info);
    expect(_passo(ps, 'desperdicio').texto, contains('Nada registado'));
    expect(_passo(ps, 'vendas').estado, EstadoPasso.info);
    expect(_passo(ps, 'ponto').texto, 'Ainda a trabalhar: Rita');
    expect(_passo(ps, 'ponto').estado, EstadoPasso.info);
    expect(_passo(ps, 'amanha').texto, contains('Nada agendado'));
    expect(_passo(ps, 'compras').texto, '5 itens por comprar');
    expect(resumoFecho(ps), contains('Tudo em ordem'));
  });

  test('singulares e links', () {
    final ps = passosFecho(
      const DadosFecho(
        semFechoPorLocal: {'Loja': 1},
        vendasN: 1,
        vendasTotal: 3,
        haccpPorFazer: 1,
        porComprar: 1,
        planoAmanha: false,
      ),
      dinheiro: _eur,
    );
    expect(_passo(ps, 'contagem').texto, 'Falta o fecho de 1 sabor: Loja (1)');
    expect(_passo(ps, 'vendas').texto, '1 venda · €3.00');
    expect(_passo(ps, 'haccp').texto, '1 controlo por fazer');
    expect(_passo(ps, 'compras').texto, '1 item por comprar');
    // sem plano, o passo leva a "Quantos assar"
    expect(_passo(ps, 'amanha').rota, '/produzir/previsao');
    expect(_passo(ps, 'contagem').rota, '/contagem');
  });
}
