import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/core/formatting/capitalizar.dart';

void main() {
  group('capitalizarInicial', () {
    test('primeira letra minúscula fica maiúscula', () {
      expect(
        capitalizarInicial('farinha de trigo T55'),
        'Farinha de trigo T55',
      );
    });

    test('já em maiúscula fica igual', () {
      expect(capitalizarInicial('Açúcar branco'), 'Açúcar branco');
    });

    test('acentuada (minúscula) fica maiúscula', () {
      expect(capitalizarInicial('óleo de girassol'), 'Óleo de girassol');
    });

    test('texto vazio devolve vazio', () {
      expect(capitalizarInicial(''), '');
    });

    test('só espaços devolve-se sem alterar', () {
      expect(capitalizarInicial('   '), '   ');
    });

    test('espaços à esquerda: maiúscula na primeira letra a sério', () {
      expect(capitalizarInicial('  farinha'), '  Farinha');
    });

    test('não mexe no resto da palavra (não força minúsculas)', () {
      expect(capitalizarInicial('fARINHA'), 'FARINHA');
    });

    test('começa por número ou símbolo: mantém-se', () {
      expect(capitalizarInicial('100% integral'), '100% integral');
    });
  });
}
