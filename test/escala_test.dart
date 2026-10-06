import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/people/domain/escala.dart';
import 'package:gc_turnkey/src/features/people/domain/ferias.dart';

void main() {
  const seg = 8 * 60;
  List<TurnoModelo> modeloAna() => [
    for (final d in [1, 2, 3, 4, 5])
      TurnoModelo(
        pessoa: 'u:1',
        diaSemana: d,
        inicio: seg,
        fim: 16 * 60 + 30,
        pausaMin: 30,
      ),
  ];

  // segunda 5 out 2026 (feriado, mas a escala não sabe disso)
  final segunda = DateTime(2026, 10, 5);

  test('horas: ler e escrever', () {
    expect(lerHora('08:30'), 510);
    expect(lerHora('8:05'), 485);
    expect(lerHora('24:00'), isNull);
    expect(lerHora('12:60'), isNull);
    expect(lerHora('abc'), isNull);
    expect(lerHora(null), isNull);
    expect(escreverHora(510), '08:30');
    expect(escreverHora(0), '00:00');
    expect(escreverHora(1440 + 90), '01:30');
  });

  test('minutos do turno: pausa e viragem da meia-noite', () {
    expect(minutosDoTurno(8 * 60, 16 * 60 + 30, 30), 8 * 60);
    expect(minutosDoTurno(22 * 60, 6 * 60, 0), 8 * 60); // noite
    expect(minutosDoTurno(8 * 60, 8 * 60, 0), 24 * 60); // fim = início: 24 h
    expect(minutosDoTurno(8 * 60, 9 * 60, 120), 0); // pausa maior que o turno
  });

  test('o horário habitual dá turno nos dias com linha e folga nos outros', () {
    final m = modeloAna();
    final qua = diaDaEscala(
      pessoa: 'u:1',
      dia: DateTime(2026, 10, 7),
      modelo: m,
      excecoes: const [],
    );
    expect(qua.estado, EstadoDia.turno);
    expect(qua.texto, '08:00–16:30');
    expect(qua.previsto, const Duration(hours: 8));
    final sab = diaDaEscala(
      pessoa: 'u:1',
      dia: DateTime(2026, 10, 10),
      modelo: m,
      excecoes: const [],
    );
    expect(sab.estado, EstadoDia.folga);
    expect(sab.texto, 'Folga');
    expect(sab.previsto, Duration.zero);
  });

  test('uma exceção muda só esse dia', () {
    final m = modeloAna();
    final ex = [
      ExcecaoEscala(
        pessoa: 'u:1',
        data: DateTime(2026, 10, 7),
        inicio: 10 * 60,
        fim: 18 * 60,
        pausaMin: 60,
      ),
      ExcecaoEscala(pessoa: 'u:1', data: DateTime(2026, 10, 8), folga: true),
      ExcecaoEscala(
        pessoa: 'u:1',
        data: DateTime(2026, 10, 10), // trabalha num sábado
        inicio: 9 * 60,
        fim: 13 * 60,
      ),
    ];
    DiaEscala d(int dia) => diaDaEscala(
      pessoa: 'u:1',
      dia: DateTime(2026, 10, dia),
      modelo: m,
      excecoes: ex,
    );
    expect(d(7).texto, '10:00–18:00');
    expect(d(7).excecao, isTrue);
    expect(d(7).previsto, const Duration(hours: 7));
    expect(d(8).estado, EstadoDia.folga);
    expect(d(8).excecao, isTrue);
    expect(d(9).excecao, isFalse); // sexta: modelo
    expect(d(10).previsto, const Duration(hours: 4));
  });

  test('férias aprovadas ganham a tudo; pedidas não', () {
    final m = modeloAna();
    Ausencia aus(EstadoAusencia e) => Ausencia(
      id: 'a',
      pessoa: 'u:1',
      nome: 'Ana',
      tipo: TipoAusencia.ferias,
      de: DateTime(2026, 10, 6),
      ate: DateTime(2026, 10, 8),
      estado: e,
    );
    final com = diaDaEscala(
      pessoa: 'u:1',
      dia: DateTime(2026, 10, 7),
      modelo: m,
      excecoes: const [],
      ausencias: [aus(EstadoAusencia.aprovado)],
    );
    expect(com.estado, EstadoDia.ausente);
    expect(com.texto, 'Férias');
    expect(com.previsto, Duration.zero);
    final pedido = diaDaEscala(
      pessoa: 'u:1',
      dia: DateTime(2026, 10, 7),
      modelo: m,
      excecoes: const [],
      ausencias: [aus(EstadoAusencia.pedido)],
    );
    expect(pedido.estado, EstadoDia.turno);
  });

  test('os dias em que a empresa não trabalha aparecem fechados', () {
    final m = [
      TurnoModelo(pessoa: 'u:1', diaSemana: 3, inicio: seg, fim: 16 * 60),
    ];
    final fechado = diaDaEscala(
      pessoa: 'u:1',
      dia: DateTime(2026, 10, 7), // quarta
      modelo: m,
      excecoes: const [],
      diasTrabalho: {1, 2, 4, 5, 6},
    );
    expect(fechado.estado, EstadoDia.fechado);
    expect(fechado.texto, 'Fechado');
    // mas uma exceção explícita ganha ao fecho (dia extra de trabalho)
    final extra = diaDaEscala(
      pessoa: 'u:1',
      dia: DateTime(2026, 10, 7),
      modelo: m,
      excecoes: [
        ExcecaoEscala(
          pessoa: 'u:1',
          data: DateTime(2026, 10, 7),
          inicio: seg,
          fim: 12 * 60,
        ),
      ],
      diasTrabalho: {1, 2, 4, 5, 6},
    );
    expect(extra.estado, EstadoDia.turno);
  });

  test('horas previstas num período', () {
    final h = horasPrevistas(
      pessoa: 'u:1',
      de: segunda,
      ate: segunda.add(const Duration(days: 7)),
      modelo: modeloAna(),
      excecoes: const [],
    );
    expect(h, const Duration(hours: 40)); // 5 × 8 h
    final semFeriasUmDia = horasPrevistas(
      pessoa: 'u:1',
      de: segunda,
      ate: segunda.add(const Duration(days: 7)),
      modelo: modeloAna(),
      excecoes: const [],
      ausencias: [
        Ausencia(
          id: 'a',
          pessoa: 'u:1',
          nome: 'Ana',
          tipo: TipoAusencia.baixa,
          de: DateTime(2026, 10, 6),
          ate: DateTime(2026, 10, 6),
          estado: EstadoAusencia.aprovado,
        ),
      ],
    );
    expect(semFeriasUmDia, const Duration(hours: 32));
  });

  test('segunda-feira da semana', () {
    expect(segundaDaSemana(DateTime(2026, 10, 7, 15)), DateTime(2026, 10, 5));
    expect(segundaDaSemana(DateTime(2026, 10, 5)), DateTime(2026, 10, 5));
    expect(segundaDaSemana(DateTime(2026, 10, 11)), DateTime(2026, 10, 5));
  });

  test('texto do saldo', () {
    expect(saldoTexto(Duration.zero), '0m');
    expect(saldoTexto(const Duration(minutes: 80)), '+1h 20m');
    expect(saldoTexto(const Duration(minutes: -35)), '−35m');
  });

  test('o mapa de horário em HTML escapa os nomes e soma as horas', () {
    final m = modeloAna();
    final dias = [
      for (var i = 0; i < 7; i++)
        diaDaEscala(
          pessoa: 'u:1',
          dia: DateTime(2026, 10, 5 + i),
          modelo: m,
          excecoes: const [],
        ),
    ];
    final html = mapaHorarioHtml(
      empresa: 'Gookie <b>',
      segunda: segunda,
      linhas: [(nome: 'Ana <script>', dias: dias)],
    );
    expect(html, contains('Mapa de horário de trabalho'));
    expect(html, contains('Ana &lt;script&gt;'));
    expect(html, isNot(contains('<script>')));
    expect(html, contains('08:00–16:30'));
    expect(html, contains('Folga'));
    expect(html, contains('40h 00m'));
    expect(html, contains('5/10 a 11/10/2026'));
  });
}
