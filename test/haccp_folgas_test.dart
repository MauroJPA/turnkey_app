import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/haccp/domain/haccp.dart';

void main() {
  const diario = ControloHaccp(
    id: 'c1',
    nome: 'Limpeza',
    tipo: TipoControlo.limpeza,
    periodicidadeDias: 1,
  );
  const semanal = ControloHaccp(
    id: 'c2',
    nome: 'Desinfestação',
    tipo: TipoControlo.manutencao,
    periodicidadeDias: 7,
  );

  RegistoHaccp reg(String controlo, DateTime d) => RegistoHaccp(
    id: '${controlo}_${d.toIso8601String()}',
    controloId: controlo,
    dataHora: d,
    valor: 0,
    conforme: true,
    responsavel: '',
    notas: '',
    acaoCorretiva: '',
    resolvido: false,
  );

  // trabalha-se de segunda a sábado; domingo é folga
  const seisDias = {1, 2, 3, 4, 5, 6};
  final sabado = DateTime(2026, 10, 10, 18);
  final domingo = DateTime(2026, 10, 11, 10);
  final segunda = DateTime(2026, 10, 12, 8);

  test('num dia de folga não há nada por fazer', () {
    final s = estadoDoControlo(
      diario,
      [reg('c1', sabado)],
      domingo,
      diasTrabalho: seisDias,
    );
    expect(s.estado, EstadoControlo.emDia);
    expect(s.fechadoHoje, isTrue);
    expect(s.precisaAcaoHoje, isFalse);
    // sem folgas configuradas, o mesmo dia pede a tarefa
    final sem = estadoDoControlo(diario, [reg('c1', sabado)], domingo);
    expect(sem.precisaAcaoHoje, isTrue);
  });

  test('a folga não conta como dia de atraso', () {
    // último registo no sábado; segunda de manhã: só falta fazer hoje
    final s = estadoDoControlo(
      diario,
      [reg('c1', sabado)],
      segunda,
      diasTrabalho: seisDias,
    );
    expect(s.estado, EstadoControlo.pendenteHoje);
    expect(s.diasAtraso, 0);
    // sem a configuração de folgas, o domingo contava como falha
    final sem = estadoDoControlo(diario, [reg('c1', sabado)], segunda);
    expect(sem.estado, EstadoControlo.atrasado);
    expect(sem.diasAtraso, 1);
  });

  test('uma falta a sério continua a contar', () {
    // último registo na quinta; segunda: faltaram sexta e sábado (domingo é folga)
    final s = estadoDoControlo(
      diario,
      [reg('c1', DateTime(2026, 10, 8, 9))],
      segunda,
      diasTrabalho: seisDias,
    );
    expect(s.estado, EstadoControlo.atrasado);
    expect(s.diasAtraso, 2);
  });

  test('o prazo semanal que cai numa folga passa para o dia aberto seguinte', () {
    // registado a 4/10 (domingo): vence a 11/10 (domingo, folga) → segunda 12/10
    final ultimo = reg('c2', DateTime(2026, 10, 4, 10));
    final domingoEstado = estadoDoControlo(
      semanal,
      [ultimo],
      domingo,
      diasTrabalho: seisDias,
    );
    expect(domingoEstado.estado, EstadoControlo.emDia);
    final seg = estadoDoControlo(
      semanal,
      [ultimo],
      segunda,
      diasTrabalho: seisDias,
    );
    expect(seg.estado, EstadoControlo.pendenteHoje);
    final terca = estadoDoControlo(
      semanal,
      [ultimo],
      DateTime(2026, 10, 13, 9),
      diasTrabalho: seisDias,
    );
    expect(terca.estado, EstadoControlo.atrasado);
    expect(terca.diasAtraso, 1);
  });

  test('estadoDosControlos passa os dias de trabalho', () {
    final r = estadoDosControlos(
      [diario],
      [reg('c1', sabado)],
      domingo,
      diasTrabalho: seisDias,
    );
    expect(r.single.fechadoHoje, isTrue);
  });
}
