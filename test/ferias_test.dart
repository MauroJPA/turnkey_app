import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/people/domain/ferias.dart';

void main() {
  Ausencia aus(
    String id,
    DateTime de,
    DateTime ate, {
    String pessoa = 'u:1',
    String nome = 'Ana',
    TipoAusencia tipo = TipoAusencia.ferias,
    EstadoAusencia estado = EstadoAusencia.aprovado,
  }) => Ausencia(
    id: id,
    pessoa: pessoa,
    nome: nome,
    tipo: tipo,
    de: de,
    ate: ate,
    estado: estado,
  );

  test('a Páscoa de vários anos', () {
    expect(pascoa(2024), DateTime(2024, 3, 31));
    expect(pascoa(2025), DateTime(2025, 4, 20));
    expect(pascoa(2026), DateTime(2026, 4, 5));
    expect(pascoa(2027), DateTime(2027, 3, 28));
  });

  test('feriados nacionais de 2026', () {
    final f = feriadosNacionais(2026);
    expect(f, hasLength(13));
    expect(f, contains(DateTime(2026, 4, 3))); // Sexta-feira Santa
    expect(f, contains(DateTime(2026, 4, 5))); // Páscoa
    expect(f, contains(DateTime(2026, 6, 4))); // Corpo de Deus
    expect(f, contains(DateTime(2026, 10, 5)));
    expect(f, contains(DateTime(2026, 12, 25)));
  });

  test('dias úteis: segunda a sexta, sem feriados', () {
    // semana de 5 a 9 out 2026: segunda 5 out é feriado → 4 dias
    expect(diasUteisEntre(DateTime(2026, 10, 5), DateTime(2026, 10, 9)), 4);
    // um fim de semana
    expect(diasUteisEntre(DateTime(2026, 10, 10), DateTime(2026, 10, 11)), 0);
    // um só dia útil
    expect(diasUteisEntre(DateTime(2026, 10, 6), DateTime(2026, 10, 6)), 1);
    // duas semanas completas sem feriados: 10
    expect(diasUteisEntre(DateTime(2026, 9, 7), DateTime(2026, 9, 18)), 10);
    // intervalo invertido
    expect(diasUteisEntre(DateTime(2026, 9, 18), DateTime(2026, 9, 7)), 0);
    // atravessa o ano (24 dez 2026 a 4 jan 2027): 24, 28, 29, 30, 31, 4 → 25 e 1 são feriados
    expect(diasUteisEntre(DateTime(2026, 12, 24), DateTime(2027, 1, 4)), 6);
  });

  test('o saldo conta só férias, aprovadas e pedidas, dentro do ano', () {
    final lista = [
      aus('a', DateTime(2026, 9, 7), DateTime(2026, 9, 11)), // 5 aprovados
      aus(
        'b',
        DateTime(2026, 9, 14),
        DateTime(2026, 9, 18),
        estado: EstadoAusencia.pedido,
      ), // 5 pedidos
      aus(
        'c',
        DateTime(2026, 9, 21),
        DateTime(2026, 9, 25),
        estado: EstadoAusencia.recusado,
      ),
      aus(
        'd',
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 2),
        tipo: TipoAusencia.baixa,
      ),
      // atravessa o ano: só conta 2026 (29, 30, 31 dez = 3 dias úteis)
      aus('e', DateTime(2026, 12, 29), DateTime(2027, 1, 8)),
    ];
    final s = calcularSaldo(direito: 22, ausencias: lista, ano: 2026);
    expect(s.gozados, 5 + 3);
    expect(s.pedidos, 5);
    expect(s.restam, 22 - 8 - 5);
    final s27 = calcularSaldo(direito: 22, ausencias: lista, ano: 2027);
    // 4, 5, 6, 7, 8 jan menos nada = 5 (1 jan feriado fica fora do intervalo)
    expect(s27.gozados, 5);
  });

  test('sobreposição ignora recusadas, outras pessoas e a própria', () {
    final lista = [
      aus('a', DateTime(2026, 9, 7), DateTime(2026, 9, 11)),
      aus(
        'r',
        DateTime(2026, 9, 14),
        DateTime(2026, 9, 18),
        estado: EstadoAusencia.recusado,
      ),
      aus('o', DateTime(2026, 9, 21), DateTime(2026, 9, 25), pessoa: 'u:2'),
    ];
    Ausencia? sobre(DateTime de, DateTime ate, {String? ignorar}) =>
        ausenciaSobreposta(
          lista,
          pessoa: 'u:1',
          de: de,
          ate: ate,
          ignorar: ignorar,
        );
    expect(sobre(DateTime(2026, 9, 11), DateTime(2026, 9, 15))?.id, 'a');
    expect(sobre(DateTime(2026, 9, 12), DateTime(2026, 9, 13)), isNull);
    expect(sobre(DateTime(2026, 9, 14), DateTime(2026, 9, 18)), isNull);
    expect(sobre(DateTime(2026, 9, 21), DateTime(2026, 9, 25)), isNull);
    expect(
      sobre(DateTime(2026, 9, 8), DateTime(2026, 9, 9), ignorar: 'a'),
      isNull,
    );
  });

  test('quem está de férias num dia', () {
    final lista = [
      aus('a', DateTime(2026, 9, 7), DateTime(2026, 9, 11)),
      aus(
        'p',
        DateTime(2026, 9, 7),
        DateTime(2026, 9, 11),
        pessoa: 'u:2',
        nome: 'Rui',
        estado: EstadoAusencia.pedido,
      ),
    ];
    expect(ausentesNoDia(lista, DateTime(2026, 9, 9)).map((a) => a.id), ['a']);
    expect(ausentesNoDia(lista, DateTime(2026, 9, 12)), isEmpty);
  });

  test('texto do período', () {
    expect(
      periodoTexto(aus('a', DateTime(2026, 9, 7), DateTime(2026, 9, 11))),
      '7/9 a 11/9',
    );
    expect(
      periodoTexto(aus('a', DateTime(2026, 9, 7), DateTime(2026, 9, 7))),
      '7/9',
    );
  });

  test('o mapa de férias só leva férias aprovadas e escapa o HTML', () {
    final html = mapaFeriasHtml(
      ano: 2026,
      empresa: 'Gookie <b>',
      ausencias: [
        aus(
          'a',
          DateTime(2026, 9, 7),
          DateTime(2026, 9, 11),
          nome: 'Ana <script>',
        ),
        aus(
          'b',
          DateTime(2026, 9, 14),
          DateTime(2026, 9, 15),
          nome: 'Ana <script>',
        ),
        aus(
          'c',
          DateTime(2026, 9, 7),
          DateTime(2026, 9, 11),
          nome: 'Rui',
          estado: EstadoAusencia.pedido,
        ),
        aus(
          'd',
          DateTime(2026, 9, 7),
          DateTime(2026, 9, 11),
          nome: 'Eva',
          tipo: TipoAusencia.baixa,
        ),
      ],
    );
    expect(html, contains('Mapa de férias 2026'));
    expect(html, contains('Ana &lt;script&gt;'));
    expect(html, isNot(contains('<script>')));
    expect(html, contains('7/9 a 11/9 · 14/9 a 15/9'));
    expect(html, contains('<td class="num">7</td>'));
    expect(html, isNot(contains('Rui')));
    expect(html, isNot(contains('Eva')));
    expect(html, contains('15 de abril e 31 de outubro'));
  });
}
