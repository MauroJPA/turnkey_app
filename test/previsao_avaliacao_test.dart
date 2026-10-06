import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/production/domain/previsao_assar.dart';

void main() {
  // hoje: quarta 7 out 2026
  final hoje = DateTime(2026, 10, 7);

  /// Vendas diárias [qtd] (do mais antigo ao mais recente) de um sabor, a
  /// terminar ontem, todos os dias menos os domingos.
  List<ConsumoDia> historia(List<double> qtd, {String ficha = 'a'}) {
    final out = <ConsumoDia>[];
    var d = hoje.subtract(const Duration(days: 1));
    for (var i = qtd.length - 1; i >= 0;) {
      if (d.weekday != DateTime.sunday) {
        out.add(ConsumoDia(dia: d, fichaId: ficha, vendido: qtd[i]));
        out.add(ConsumoDia(dia: d, fichaId: 'fundo', vendido: 1));
        i--;
      }
      d = d.subtract(const Duration(days: 1));
    }
    return out;
  }

  test('vendas constantes: a previsão acerta e o erro é zero', () {
    final c = historia(List.filled(60, 20));
    final a = avaliarPrevisoes(hoje: hoje, consumo: c);
    expect(a, hasLength(7));
    for (final dia in a) {
      expect(dia.vendido, greaterThan(0));
      expect(dia.erroPct, closeTo(0, 1e-6));
    }
    expect(erroMedioPct(a), closeTo(0, 1e-6));
    // do mais recente para o mais antigo, sem domingos
    expect(a.first.dia, DateTime(2026, 10, 6));
    expect(a.any((d) => d.dia.weekday == DateTime.sunday), isFalse);
  });

  test('um dia fora do normal aparece com erro e desvio', () {
    final qtd = List<double>.filled(60, 20);
    qtd[qtd.length - 1] = 40; // ontem vendeu o dobro
    final a = avaliarPrevisoes(hoje: hoje, consumo: historia(qtd));
    final ontem = a.first;
    expect(ontem.vendido, greaterThan(ontem.previsto));
    expect(ontem.erroPct, greaterThan(10));
    expect(ontem.desvioPct, lessThan(0)); // faltou
    expect(ontem.piores.first.fichaId, anyOf('a', 'fundo'));
  });

  test('só avalia dias de trabalho e salta os sem vendas', () {
    final c = historia(List.filled(60, 20));
    final a = avaliarPrevisoes(
      hoje: hoje,
      consumo: c,
      diasTrabalho: {1, 2, 3, 4, 5}, // sábado é folga
    );
    expect(a.any((d) => d.dia.weekday == DateTime.saturday), isFalse);
    expect(a, hasLength(7));
  });

  test('sem histórico não há avaliação', () {
    expect(avaliarPrevisoes(hoje: hoje, consumo: const []), isEmpty);
    expect(erroMedioPct(const []), isNull);
  });

  test('o erro médio é ponderado pelo vendido', () {
    final a = [
      AvaliacaoDia(
        dia: DateTime(2026, 10, 6),
        previsto: 90,
        vendido: 100,
        erroAbsoluto: 10,
      ),
      AvaliacaoDia(
        dia: DateTime(2026, 10, 5),
        previsto: 10,
        vendido: 20,
        erroAbsoluto: 10,
      ),
    ];
    expect(erroMedioPct(a), closeTo(20 / 120 * 100, 1e-9));
    expect(a[1].desvioPct, closeTo(-50, 1e-9));
    expect(a[0].erroPct, closeTo(10, 1e-9));
  });
}
