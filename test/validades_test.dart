import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/traceability/domain/validades.dart';

void main() {
  final hoje = DateTime(2026, 10, 6, 15);
  DateTime d(int dia, [int mes = 10]) => DateTime(2026, mes, dia);

  LoteIngredienteAviso ing(
    String nome,
    DateTime? val, {
    bool esgotado = false,
    String id = 'i',
  }) =>
      (id: id, nome: nome, lote: 'L-$nome', validade: val, esgotado: esgotado);

  LoteProdutoAviso prod(
    String nome,
    DateTime? val, {
    double qtd = 24,
    bool esgotado = false,
    String id = 'p',
  }) => (
    id: id,
    nome: nome,
    lote: '261006-$nome',
    validade: val,
    quantidade: qtd,
    esgotado: esgotado,
  );

  test('ingredientes: avisa dentro de 5 dias e depois de vencido', () {
    final r = alertasDeValidade(
      hoje: hoje,
      ingredientes: [
        ing('Leite', d(6), id: 'a'), // hoje
        ing('Natas', d(11), id: 'b'), // 5 dias
        ing('Farinha', d(12), id: 'c'), // 6 dias: ainda cedo
        ing('Ovos', d(3), id: 'e'), // vencido há 3 dias
      ],
    );
    expect(r.map((a) => a.id), ['e', 'a', 'b']);
    expect(r.map((a) => a.quando), [
      'vencido há 3 dias',
      'vence hoje',
      'vence em 5 dias',
    ]);
    expect(r.first.vencido, isTrue);
  });

  test('o que está esgotado, sem validade ou vencido há muito não avisa', () {
    final r = alertasDeValidade(
      hoje: hoje,
      ingredientes: [
        ing('Leite', d(6), esgotado: true),
        ing('Sal', null),
        ing('Mel', d(20, 9)), // vencido há mais de 14 dias
      ],
    );
    expect(r, isEmpty);
  });

  test('produtos: hoje e amanhã, com a quantidade', () {
    final r = alertasDeValidade(
      hoje: hoje,
      produtos: [
        prod('ALB', d(7), id: 'a'), // amanhã
        prod('PRO', d(8), id: 'b'), // depois de amanhã: ainda não
        prod('BEL', d(5), id: 'c', qtd: 12), // ontem
        prod('GOI', d(6), id: 'd', qtd: 0), // nada para vender
        prod('VIE', d(6), id: 'e', esgotado: true),
      ],
    );
    expect(r.map((a) => a.id), ['c', 'a']);
    expect(r.last.quando, 'vence amanhã');
    expect(r.first.texto, 'BEL · lote 261006-BEL (12 un) — vencido há 1 dia');
  });

  test('ordem: primeiro os que vencem antes; empate por nome', () {
    final r = alertasDeValidade(
      hoje: hoje,
      ingredientes: [
        ing('Zeta', d(7), id: 'z'),
        ing('Alfa', d(7), id: 'a'),
      ],
      produtos: [prod('ALB', d(6), id: 'p')],
    );
    expect(r.map((a) => a.id), ['p', 'a', 'z']);
    expect(r.first.tipo, TipoValidade.produto);
  });
}
