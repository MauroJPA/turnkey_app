import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/dashboard/domain/arranque.dart';

void main() {
  Arranque lista(List<(String, bool)> ps) =>
      Arranque([for (final (c, f) in ps) PassoArranque(chave: c, feito: f)]);

  test('lê o que o servidor devolve', () {
    final a = Arranque.fromJson({
      'passos': [
        {'chave': 'empresa', 'feito': true, 'detalhe': 'Logótipo definido'},
        {'chave': 'ingredientes', 'feito': false, 'detalhe': '1 ingrediente'},
        {'chave': 'lixo'},
        'não é um passo',
      ],
      'feitos': 1,
      'total': 3,
    });
    expect(a.passos.map((p) => p.chave), ['empresa', 'ingredientes', 'lixo']);
    expect(a.passos.first.feito, isTrue);
    expect(a.passos[1].detalhe, '1 ingrediente');
    expect(a.passos.last.feito, isFalse);
  });

  test('progresso, o que falta e quando está completo', () {
    final a = lista([('a', true), ('b', false), ('c', true), ('d', false)]);
    expect(a.total, 4);
    expect(a.feitos, 2);
    expect(a.progresso, 0.5);
    expect(a.porFazer.map((p) => p.chave), ['b', 'd']);
    expect(a.completo, isFalse);
    expect(lista([('a', true), ('b', true)]).completo, isTrue);
    expect(
      const Arranque([]).completo,
      isFalse,
    ); // sem dados não "está tudo feito"
    expect(const Arranque([]).progresso, 1);
  });

  test('todos os passos do servidor têm texto e destino (ou ajuda)', () {
    for (final chave in [
      'empresa',
      'dias',
      'ingredientes',
      'precos',
      'receitas',
      'fichas',
      'equipa',
      'horarios',
      'avisos',
      'ia',
      'backups',
      'vigia',
    ]) {
      final i = infoPasso(chave);
      expect(i.titulo, isNot(chave), reason: chave);
      expect(
        i.rota != null || i.ajuda.isNotEmpty,
        isTrue,
        reason: '$chave precisa de rota ou ajuda',
      );
    }
    // um passo que a app não conhece não rebenta
    expect(infoPasso('novo').titulo, 'novo');
  });
}
