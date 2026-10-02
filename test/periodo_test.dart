import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/finance/domain/periodo.dart';

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

    test('semanaAtual começa num domingo e acaba num sábado, 7 dias', () {
      final p = Periodo.semanaAtual();
      expect(p.desde.weekday, DateTime.sunday);
      expect(p.ate.weekday, DateTime.saturday);
      expect(p.dias, 7);
      expect(p.contem(DateTime.now()), isTrue);
    });

    test('mesAtual é o mês inteiro, do dia 1 ao último dia', () {
      final p = Periodo.mesAtual();
      final n = DateTime.now();
      expect(p.desde, DateTime(n.year, n.month, 1));
      expect(p.ate, DateTime(n.year, n.month + 1, 0));
    });
  });

  group('semanaDe (domingo a sábado, ignora o mês)', () {
    final hoje = DateTime(2026, 10, 2); // sexta-feira
    test('qualquer dia da semana dá o mesmo intervalo', () {
      for (var d = 4; d <= 10; d++) {
        final p = Periodo.semanaDe(DateTime(2026, 10, d), hoje: hoje);
        expect(p.desde, DateTime(2026, 10, 4), reason: 'dia $d');
        expect(p.ate, DateTime(2026, 10, 10), reason: 'dia $d');
      }
    });

    test('atravessa a mudança de mês', () {
      final p = Periodo.semanaDe(DateTime(2026, 9, 30), hoje: hoje);
      expect(p.desde, DateTime(2026, 9, 27));
      expect(p.ate, DateTime(2026, 10, 3));
      expect(p.dias, 7);
      expect(p.intervaloTexto, '27/09/2026 – 03/10/2026');
    });

    test('atravessa a mudança de ano', () {
      final p = Periodo.semanaDe(DateTime(2026, 12, 31), hoje: hoje);
      expect(p.desde, DateTime(2026, 12, 27));
      expect(p.ate, DateTime(2027, 1, 2));
    });

    test('tem sempre 7 dias, mesmo com a mudança de hora', () {
      expect(Periodo.semanaDe(DateTime(2026, 3, 31), hoje: hoje).dias, 7);
      expect(Periodo.semanaDe(DateTime(2026, 10, 27), hoje: hoje).dias, 7);
    });

    test('rótulos: esta semana, semana passada, outra', () {
      expect(Periodo.semanaDe(hoje, hoje: hoje).label, 'Esta semana');
      expect(
        Periodo.semanaDe(DateTime(2026, 9, 25), hoje: hoje).label,
        'Semana passada',
      );
      expect(
        Periodo.semanaDe(DateTime(2026, 9, 10), hoje: hoje).label,
        'Semana de 06/09',
      );
    });

    test('anterior e seguinte andam uma semana', () {
      final p = Periodo.semanaDe(hoje, hoje: hoje);
      // hoje (sex. 02/10) está na semana 27/09 – 03/10
      expect(p.desde, DateTime(2026, 9, 27));
      expect(p.ate, DateTime(2026, 10, 3));
      expect(p.anterior.desde, DateTime(2026, 9, 20));
      expect(p.anterior.ate, DateTime(2026, 9, 26));
      expect(p.seguinte.desde, DateTime(2026, 10, 4));
      expect(p.seguinte.ate, DateTime(2026, 10, 10));
    });

    test('fator de prorrateio é sempre 7/30,44', () {
      final a = Periodo.semanaDe(DateTime(2026, 10, 7)); // dentro do mês
      final b = Periodo.semanaDe(DateTime(2026, 9, 30)); // atravessa o mês
      expect(a.fatorProrateioMensal, closeTo(7 / 30.44, 1e-9));
      expect(b.fatorProrateioMensal, closeTo(7 / 30.44, 1e-9));
    });
  });

  group('mesDe (mês civil completo)', () {
    final hoje = DateTime(2026, 10, 2);
    test('dia 1 ao último dia', () {
      final p = Periodo.mesDe(DateTime(2026, 10, 17), hoje: hoje);
      expect(p.desde, DateTime(2026, 10, 1));
      expect(p.ate, DateTime(2026, 10, 31));
      expect(p.dias, 31);
      expect(p.intervaloTexto, '01/10/2026 – 31/10/2026');
      expect(p.fatorProrateioMensal, closeTo(1.0, 1e-9));
    });

    test('fevereiro de ano bissexto', () {
      final p = Periodo.mesDe(DateTime(2028, 2, 10), hoje: hoje);
      expect(p.ate, DateTime(2028, 2, 29));
    });

    test('rótulos: este mês, mês passado, outro', () {
      expect(Periodo.mesDe(hoje, hoje: hoje).label, 'Este mês');
      expect(Periodo.mesDe(DateTime(2026, 9, 5), hoje: hoje).label, 'Mês passado');
      expect(
        Periodo.mesDe(DateTime(2026, 3, 5), hoje: hoje).label,
        'março de 2026',
      );
    });

    test('mês passado em janeiro é dezembro do ano anterior', () {
      final p = Periodo.mesDe(DateTime(2025, 12, 31), hoje: DateTime(2026, 1, 15));
      expect(p.label, 'Mês passado');
      expect(p.desde, DateTime(2025, 12, 1));
    });

    test('anterior é o mês civil anterior (não "31 dias antes")', () {
      final p = Periodo.mesDe(DateTime(2026, 3, 10), hoje: hoje);
      expect(p.anterior.desde, DateTime(2026, 2, 1));
      expect(p.anterior.ate, DateTime(2026, 2, 28));
      expect(p.seguinte.desde, DateTime(2026, 4, 1));
      expect(p.seguinte.ate, DateTime(2026, 4, 30));
    });

    test('janeiro → dezembro anterior', () {
      final p = Periodo.mesDe(DateTime(2026, 1, 10), hoje: hoje);
      expect(p.anterior.desde, DateTime(2025, 12, 1));
      expect(p.anterior.ate, DateTime(2025, 12, 31));
    });
  });

  group('anoDe (ano civil completo)', () {
    final hoje = DateTime(2026, 10, 2);
    test('1 de janeiro a 31 de dezembro', () {
      final p = Periodo.anoDe(DateTime(2026, 6, 15), hoje: hoje);
      expect(p.desde, DateTime(2026, 1, 1));
      expect(p.ate, DateTime(2026, 12, 31));
      expect(p.dias, 365);
      expect(p.intervaloTexto, '01/01/2026 – 31/12/2026');
      expect(p.label, 'Este ano');
    });

    test('ano bissexto tem 366 dias', () {
      expect(Periodo.anoDe(DateTime(2028, 3, 1), hoje: hoje).dias, 366);
    });

    test('rótulos e navegação', () {
      expect(Periodo.anoDe(DateTime(2025, 5, 1), hoje: hoje).label, 'Ano passado');
      expect(Periodo.anoDe(DateTime(2024, 5, 1), hoje: hoje).label, '2024');
      final p = Periodo.anoDe(hoje, hoje: hoje);
      expect(p.anterior.desde, DateTime(2025, 1, 1));
      expect(p.anterior.ate, DateTime(2025, 12, 31));
      expect(p.seguinte.desde, DateTime(2027, 1, 1));
    });

    test('um ano pesa 12 meses nos custos mensais', () {
      expect(Periodo.anoDe(DateTime(2026, 1, 1)).fatorProrateioMensal, 12);
      expect(Periodo.anoDe(DateTime(2028, 1, 1)).fatorProrateioMensal, 12);
    });
  });

  group('Periodo livre', () {
    test('anterior tem a mesma duração', () {
      final p = Periodo(
        desde: DateTime(2026, 3, 25),
        ate: DateTime(2026, 3, 31),
        label: 'x',
      );
      expect(p.anterior.desde, DateTime(2026, 3, 18));
      expect(p.anterior.ate, DateTime(2026, 3, 24));
    });
  });
}
