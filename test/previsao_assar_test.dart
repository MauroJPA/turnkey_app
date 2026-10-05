import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/production/domain/previsao_assar.dart';

void main() {
  // Hoje: quarta 7 out 2026; amanhã: quinta 8 out 2026.
  final hoje = DateTime(2026, 10, 7);
  final alvo = DateTime(2026, 10, 8);

  /// Vendas de [qtd] por quinta-feira das últimas semanas (a mais antiga
  /// primeiro), mais uma venda "de fundo" para a loja estar aberta nesses dias.
  List<ConsumoDia> quintas(List<double> qtd, {String ficha = 'a'}) {
    final out = <ConsumoDia>[];
    for (var i = 0; i < qtd.length; i++) {
      final semanasAtras = qtd.length - i;
      final d = alvo.subtract(Duration(days: 7 * semanasAtras));
      out.add(ConsumoDia(dia: d, fichaId: ficha, vendido: qtd[i]));
      out.add(ConsumoDia(dia: d, fichaId: 'fundo', vendido: 1));
    }
    return out;
  }

  PrevisaoFicha de(List<ConsumoDia> c, {double ajuste = 0, String id = 'a'}) =>
      preverDia(
        hoje: hoje,
        alvo: alvo,
        consumo: c,
        ajustePct: ajuste,
      ).firstWhere((x) => x.fichaId == id);

  test('modelos: última, média, mediana e recente', () {
    final h = [10.0, 20.0, 30.0, 40.0];
    expect(preverComModelo(ModeloPrevisao.ultima, h), 40);
    expect(preverComModelo(ModeloPrevisao.media, h), 25);
    expect(preverComModelo(ModeloPrevisao.mediana, h), 25);
    final r = preverComModelo(ModeloPrevisao.recente, h);
    expect(r, greaterThan(25)); // mais peso ao 40
    expect(r, lessThan(40));
    expect(preverComModelo(ModeloPrevisao.media, const []), 0);
  });

  test('erro do modelo só existe com dias para testar', () {
    expect(erroDoModelo(ModeloPrevisao.media, [1, 2, 3]), isNull);
    expect(erroDoModelo(ModeloPrevisao.media, [5, 5, 5, 5, 5]), 0);
  });

  test('escolhe o modelo que errou menos', () {
    final sobe = <double>[10, 12, 14, 16, 18, 20, 22, 24];
    final m = melhorModelo(sobe);
    expect(m.modelo, anyOf(ModeloPrevisao.ultima, ModeloPrevisao.recente));
    expect(m.erro, isNotNull);
    // com dias fora de série, a última semana é o pior modelo
    final pico = <double>[10, 10, 10, 50, 10, 10, 50, 10, 10];
    expect(melhorModelo(pico).modelo, isNot(ModeloPrevisao.ultima));
  });

  test('previsão para um dia com histórico constante', () {
    final p = de(quintas(List.filled(8, 20)));
    expect(p.previsto, closeTo(20, 1e-9));
    expect(p.sugerido, 20); // erro 0 → sem margem
    expect(p.pontos, 8);
    expect(p.confianca, Confianca.alta);
    expect(p.deFallback, isFalse);
  });

  test('a margem vem do erro e o ajuste do dia multiplica', () {
    final consumo = quintas([20, 24, 16, 22, 18, 20, 24, 16]);
    final p = de(consumo);
    expect(p.erroMedio, isNotNull);
    expect(p.margem, closeTo(p.erroMedio!, 1e-9));
    expect(p.sugerido, (p.previsto + p.margem).round());
    final mais = de(consumo, ajuste: 50);
    expect(mais.previsto, closeTo(p.previsto * 1.5, 1e-9));
    expect(mais.sugerido, greaterThan(p.sugerido));
  });

  test('desperdício alto tira a margem de segurança', () {
    final ontem = hoje.subtract(const Duration(days: 1));
    final p = de([
      ...quintas([20, 24, 16, 22, 18, 20, 24, 16]),
      ConsumoDia(dia: ontem, fichaId: 'a', desperdicio: 70),
    ]);
    expect(p.desperdicioPct, greaterThanOrEqualTo(desperdicioSemMargem));
    expect(p.margem, 0);
    expect(p.sugerido, p.previsto.round());
  });

  test('desperdício médio reduz a margem a metade', () {
    final base = quintas([20, 24, 16, 22, 18, 20, 24, 16]);
    final ontem = hoje.subtract(const Duration(days: 1));
    final sem = de(base);
    final p = de([
      ...base,
      ConsumoDia(dia: ontem, fichaId: 'a', desperdicio: 10),
    ]);
    expect(p.desperdicioPct, inInclusiveRange(5, 15));
    expect(p.margem, closeTo(sem.margem / 2, 1e-9));
  });

  test('pouco histórico: média geral e confiança baixa', () {
    final p = de(quintas([30]));
    expect(p.deFallback, isTrue);
    expect(p.confianca, Confianca.baixa);
    expect(p.sugerido, greaterThan(0));
  });

  test('dias em que a loja não vendeu nada não contam como zero', () {
    DateTime d(int s) => alvo.subtract(Duration(days: 7 * s));
    final consumo = [
      for (final s in [1, 3, 4]) ...[
        ConsumoDia(dia: d(s), fichaId: 'a', vendido: 20),
        ConsumoDia(dia: d(s), fichaId: 'fundo', vendido: 1),
      ],
    ];
    final p = de(consumo);
    expect(p.pontos, 3);
    expect(p.previsto, closeTo(20, 1e-9));
  });

  test('ignora hoje, o futuro e o que é antigo demais', () {
    final consumo = [
      ConsumoDia(dia: hoje, fichaId: 'a', vendido: 99),
      ConsumoDia(
        dia: hoje.add(const Duration(days: 3)),
        fichaId: 'a',
        vendido: 99,
      ),
      ConsumoDia(
        dia: hoje.subtract(const Duration(days: 400)),
        fichaId: 'a',
        vendido: 99,
      ),
    ];
    expect(preverDia(hoje: hoje, alvo: alvo, consumo: consumo), isEmpty);
  });

  test('ordena por sugestão decrescente', () {
    final c = [
      ...quintas(List.filled(6, 10), ficha: 'pouco'),
      ...quintas(List.filled(6, 40), ficha: 'muito'),
    ];
    final r = preverDia(hoje: hoje, alvo: alvo, consumo: c);
    expect(r.first.fichaId, 'muito');
  });
}
