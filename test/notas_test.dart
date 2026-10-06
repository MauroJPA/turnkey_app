import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/people/domain/nota.dart';

void main() {
  Nota nota(
    String id, {
    String texto = 'texto',
    String titulo = '',
    CategoriaNota cat = CategoriaNota.recado,
    bool fixada = false,
    bool arquivada = false,
    DateTime? lembrar,
    DateTime? criada,
    String autor = 'Ana',
  }) => Nota(
    id: id,
    texto: texto,
    titulo: titulo,
    categoria: cat,
    fixada: fixada,
    arquivada: arquivada,
    lembrarEm: lembrar,
    criada: criada ?? DateTime(2026, 10, 1),
    autorNome: autor,
  );

  test('fixadas primeiro, depois as mais recentes', () {
    final r = ordenarNotas([
      nota('a', criada: DateTime(2026, 10, 1)),
      nota('b', criada: DateTime(2026, 10, 3)),
      nota('c', criada: DateTime(2026, 9, 1), fixada: true),
      nota('d', criada: DateTime(2026, 10, 2)),
    ]);
    expect(r.map((n) => n.id), ['c', 'b', 'd', 'a']);
  });

  test('filtrar por categoria e por texto (título, texto, autor)', () {
    final todas = [
      nota('a', texto: 'Comprar manteiga', cat: CategoriaNota.lembrete),
      nota('b', texto: 'Forno avariado', cat: CategoriaNota.ocorrencia),
      nota('c', titulo: 'MANTEIGA', texto: 'x', autor: 'Rui'),
    ];
    expect(
      filtrarNotas(todas, categoria: CategoriaNota.ocorrencia).map((n) => n.id),
      ['b'],
    );
    expect(filtrarNotas(todas, busca: 'manteiga').map((n) => n.id).toSet(), {
      'a',
      'c',
    });
    expect(filtrarNotas(todas, busca: ' rui ').map((n) => n.id), ['c']);
    expect(filtrarNotas(todas), hasLength(3));
  });

  test(
    'um lembrete aparece a partir do dia e deixa de aparecer se arquivado',
    () {
      final hoje = DateTime(2026, 10, 6, 15);
      expect(nota('a', lembrar: DateTime(2026, 10, 6)).paraHoje(hoje), isTrue);
      expect(nota('a', lembrar: DateTime(2026, 10, 1)).paraHoje(hoje), isTrue);
      expect(nota('a', lembrar: DateTime(2026, 10, 7)).paraHoje(hoje), isFalse);
      expect(nota('a').paraHoje(hoje), isFalse);
      expect(
        nota(
          'a',
          lembrar: DateTime(2026, 10, 1),
          arquivada: true,
        ).paraHoje(hoje),
        isFalse,
      );
    },
  );

  test('há quanto tempo', () {
    final agora = DateTime(2026, 10, 6, 15, 0);
    expect(quandoTexto(DateTime(2026, 10, 6, 14, 59, 40), agora), 'agora');
    expect(quandoTexto(DateTime(2026, 10, 6, 14, 30), agora), 'há 30 min');
    expect(quandoTexto(DateTime(2026, 10, 6, 11, 0), agora), 'há 4 h');
    expect(quandoTexto(DateTime(2026, 10, 5, 22, 0), agora), 'ontem');
    expect(quandoTexto(DateTime(2026, 10, 1), agora), '1/10');
    expect(quandoTexto(DateTime(2025, 12, 24), agora), '24/12/2025');
  });
}
