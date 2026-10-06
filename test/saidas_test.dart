import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/people/domain/escala.dart';
import 'package:gc_turnkey/src/features/people/domain/ponto.dart';

void main() {
  var n = 0;
  RegistoPonto r(
    String pessoa,
    TipoPonto t,
    DateTime q, {
    String nome = 'Ana',
  }) => RegistoPonto(
    id: '${n++}',
    pessoa: pessoa,
    nome: nome,
    tipo: t,
    dataHora: q,
  );

  DateTime h(int hora, [int min = 0, int dia = 6]) =>
      DateTime(2026, 10, dia, hora, min);

  List<SaidaPorMarcar> falta(
    List<RegistoPonto> regs,
    DateTime agora, {
    DateTime? Function(String, DateTime)? fim,
  }) => saidasPorMarcar(calcularJornadas(regs, agora), agora, fimPrevisto: fim);

  test('quem está dentro do turno não aparece', () {
    final e = [r('u:1', TipoPonto.entrada, h(8))];
    expect(falta(e, h(12), fim: (_, __) => h(16, 30)), isEmpty);
    // sem escala e com poucas horas: também não
    expect(falta(e, h(15)), isEmpty);
  });

  test('passada uma hora do fim do turno, avisa', () {
    final e = [r('u:1', TipoPonto.entrada, h(8))];
    DateTime? fim(String _, DateTime __) => h(16, 30);
    expect(falta(e, h(17, 29), fim: fim), isEmpty);
    final l = falta(e, h(17, 31), fim: fim);
    expect(l, hasLength(1));
    expect(l.single.nome, 'Ana');
    expect(l.single.fimPrevisto, h(16, 30));
    expect(
      l.single.texto(h(17, 31)),
      'Ana — entrada às 08:00 (turno até 16:30)',
    );
  });

  test('uma entrada de ontem sem saída avisa sempre', () {
    final e = [r('u:1', TipoPonto.entrada, h(8, 0, 5))];
    final l = falta(e, h(9));
    expect(l.single.texto(h(9)), 'Ana — entrada a 5/10 às 08:00');
  });

  test('quem já marcou a saída não aparece', () {
    final e = [
      r('u:1', TipoPonto.entrada, h(8)),
      r('u:1', TipoPonto.saida, h(16, 30)),
    ];
    expect(falta(e, h(20), fim: (_, __) => h(16, 30)), isEmpty);
  });

  test('turno da noite: ainda dentro do turno às 06:00 não avisa', () {
    final e = [r('u:1', TipoPonto.entrada, h(22, 0, 5))];
    DateTime? fim(String _, DateTime __) => h(6, 0, 6);
    expect(falta(e, h(5, 30), fim: fim), isEmpty);
    expect(falta(e, h(7, 30), fim: fim), hasLength(1));
  });

  test('uma linha por pessoa, só da jornada mais recente', () {
    final e = [
      r('u:1', TipoPonto.entrada, h(8, 0, 4)), // esquecida há dois dias
      r('u:1', TipoPonto.entrada, h(8, 0, 5)), // e a seguinte também
      r('c:2', TipoPonto.entrada, h(7, 0, 5), nome: 'Rui'),
    ];
    final l = falta(e, h(9));
    expect(l.map((x) => x.nome), ['Rui', 'Ana']);
    expect(l.firstWhere((x) => x.nome == 'Ana').entrada, h(8, 0, 5));
  });

  test('o fim do turno: dia seguinte se passa da meia-noite', () {
    DiaEscala d(int ini, int fim) => DiaEscala(
      dia: DateTime(2026, 10, 5),
      estado: EstadoDia.turno,
      inicio: ini,
      fim: fim,
    );
    expect(fimDoTurno(d(8 * 60, 16 * 60 + 30)), DateTime(2026, 10, 5, 16, 30));
    expect(fimDoTurno(d(22 * 60, 6 * 60)), DateTime(2026, 10, 6, 6, 0));
    expect(
      fimDoTurno(
        DiaEscala(dia: DateTime(2026, 10, 5), estado: EstadoDia.folga),
      ),
      isNull,
    );
  });
}
