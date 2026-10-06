import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/pricing/domain/cost_config.dart';
import 'package:gc_turnkey/src/features/pricing/domain/dias_trabalho.dart';
import 'package:gc_turnkey/src/features/production/domain/previsao_assar.dart';

void main() {
  test('ler e escrever os dias de trabalho', () {
    expect(lerDiasTrabalho('1,2,3,4,5,6'), {1, 2, 3, 4, 5, 6});
    expect(lerDiasTrabalho(' 2 , 4 '), {2, 4});
    // vazio, lixo ou fora de 1–7 = todos os dias
    expect(lerDiasTrabalho(''), todosOsDias);
    expect(lerDiasTrabalho(null), todosOsDias);
    expect(lerDiasTrabalho('x,9,0'), todosOsDias);
    expect(escreverDiasTrabalho({6, 1, 3}), '1,3,6');
    expect(escreverDiasTrabalho(todosOsDias), '');
    expect(escreverDiasTrabalho({}), '');
  });

  test('resumo em texto', () {
    expect(resumoDiasTrabalho(todosOsDias), 'todos os dias');
    expect(resumoDiasTrabalho({1, 2, 3, 4, 5, 6}), 'segunda a sábado');
    expect(resumoDiasTrabalho({1, 2, 3, 4, 5}), 'segunda a sexta');
    expect(resumoDiasTrabalho({1, 3, 5}), 'seg, qua, sex');
  });

  test('próximo dia de trabalho', () {
    final sabado = DateTime(2026, 10, 10);
    final seisDias = {1, 2, 3, 4, 5, 6};
    expect(proximoDiaDeTrabalho(sabado, seisDias), sabado);
    // domingo é folga: segue a segunda
    expect(
      proximoDiaDeTrabalho(DateTime(2026, 10, 11), seisDias),
      DateTime(2026, 10, 12),
    );
  });

  test('a configuração guarda e lê os dias', () {
    const c = CostConfig(diasTrabalho: '1,2,3,4,5');
    expect(c.diasDeTrabalho, {1, 2, 3, 4, 5});
    expect(c.toBody()['dias_trabalho'], '1,2,3,4,5');
    expect(const CostConfig().diasDeTrabalho, todosOsDias);
    expect(c.copyWith(cmv: 30).diasTrabalho, '1,2,3,4,5');
  });

  group('previsão e dias de folga', () {
    final hoje = DateTime(2026, 10, 7); // quarta
    final domingo = DateTime(2026, 10, 11);
    final quinta = DateTime(2026, 10, 8);

    List<ConsumoDia> semanas(DateTime alvo) {
      final out = <ConsumoDia>[];
      for (var s = 1; s <= 6; s++) {
        final d = alvo.subtract(Duration(days: 7 * s));
        out
          ..add(ConsumoDia(dia: d, fichaId: 'a', vendido: 10))
          ..add(ConsumoDia(dia: d, fichaId: 'fundo', vendido: 1));
      }
      return out;
    }

    test('um dia de folga não tem previsão', () {
      final c = semanas(domingo);
      expect(
        preverDia(hoje: hoje, alvo: domingo, consumo: c),
        isNotEmpty,
        reason: 'sem configuração, trabalha-se todos os dias',
      );
      expect(
        preverDia(
          hoje: hoje,
          alvo: domingo,
          consumo: c,
          diasTrabalho: {1, 2, 3, 4, 5, 6},
        ),
        isEmpty,
      );
    });

    test('um dia de trabalho continua a ter previsão', () {
      final r = preverDia(
        hoje: hoje,
        alvo: quinta,
        consumo: semanas(quinta),
        diasTrabalho: {1, 2, 3, 4, 5, 6},
      );
      final a = r.firstWhere((x) => x.fichaId == 'a');
      expect(a.previsto, closeTo(10, 1e-9));
    });

    test('hoje também se prevê, sem contar as vendas de hoje no histórico', () {
      final c = [
        ...semanas(hoje),
        ConsumoDia(dia: hoje, fichaId: 'a', vendido: 99),
      ];
      final r = preverDia(hoje: hoje, alvo: hoje, consumo: c);
      expect(r.firstWhere((x) => x.fichaId == 'a').previsto, closeTo(10, 1e-9));
    });
  });
}
