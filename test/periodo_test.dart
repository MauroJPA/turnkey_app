import 'package:flutter_test/flutter_test.dart';
import 'package:turnkey_app/src/features/finance/domain/periodo.dart';

void main() {
  group('Periodo.anterior', () {
    test('período anterior tem a mesma duração e termina no dia antes', () {
      final p = Periodo(
        desde: DateTime(2026, 9, 8),
        ate: DateTime(2026, 9, 14),
        label: 'x',
      );
      expect(p.dias, 7);
      final a = p.anterior;
      expect(a.dias, 7);
      expect(a.ate, DateTime(2026, 9, 7));
      expect(a.desde, DateTime(2026, 9, 1));
    });
  });

  group('Periodo.fatorProrateioMensal', () {
    test('mês completo dá fator 1.0', () {
      final p = Periodo(
        desde: DateTime(2026, 9, 1),
        ate: DateTime(2026, 9, 30),
        label: 'x',
      );
      expect(p.fatorProrateioMensal, closeTo(1.0, 0.001));
    });

    test('uma semana dá ~7/30', () {
      final p = Periodo(
        desde: DateTime(2026, 9, 1),
        ate: DateTime(2026, 9, 7),
        label: 'x',
      );
      expect(p.fatorProrateioMensal, closeTo(7 / 30, 0.01));
    });

    test('fevereiro (28 dias) completo também dá fator 1.0', () {
      final p = Periodo(
        desde: DateTime(2026, 2, 1),
        ate: DateTime(2026, 2, 28),
        label: 'x',
      );
      expect(p.fatorProrateioMensal, closeTo(1.0, 0.001));
    });
  });

  group('Periodo == / hashCode', () {
    test('igualdade por valor (desde/ate), não identidade', () {
      final a = Periodo(desde: DateTime(2026, 1, 1), ate: DateTime(2026, 1, 7), label: 'a');
      final b = Periodo(desde: DateTime(2026, 1, 1), ate: DateTime(2026, 1, 7), label: 'b');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });

  group('presets', () {
    test('mesPassado é sempre um mês civil completo', () {
      final p = Periodo.mesPassado();
      expect(p.desde.day, 1);
      // último dia do mês passado == último dia antes do dia 1 deste mês
      final proximoDia = p.ate.add(const Duration(days: 1));
      expect(proximoDia.day, 1);
    });

    test('semanaAtual começa numa segunda-feira', () {
      final p = Periodo.semanaAtual();
      expect(p.desde.weekday, DateTime.monday);
    });
  });
}
