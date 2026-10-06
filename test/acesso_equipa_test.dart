import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/core/auth/permissions.dart';
import 'package:gc_turnkey/src/features/settings/domain/acesso_equipa.dart';

void main() {
  group('podeGerirAcesso', () {
    bool pode(Papel eu, Papel alvo, {bool souEu = false}) =>
        podeGerirAcesso(eu: eu, alvo: alvo, souEu: souEu);

    test('o proprietário gere qualquer pessoa, menos a si próprio', () {
      for (final alvo in Papel.values) {
        expect(pode(Papel.owner, alvo), isTrue, reason: alvo.name);
      }
      expect(pode(Papel.owner, Papel.owner, souEu: true), isFalse);
    });

    test('o administrador só gere Editores e Leitores', () {
      expect(pode(Papel.admin, Papel.editor), isTrue);
      expect(pode(Papel.admin, Papel.viewer), isTrue);
      expect(pode(Papel.admin, Papel.admin), isFalse);
      expect(pode(Papel.admin, Papel.owner), isFalse);
    });

    test('Editor e Leitura não gerem ninguém', () {
      for (final alvo in Papel.values) {
        expect(pode(Papel.editor, alvo), isFalse);
        expect(pode(Papel.viewer, alvo), isFalse);
      }
    });
  });

  group('validarSenhaNova', () {
    test('curta, diferente, certa', () {
      expect(validarSenhaNova('abc', 'abc'), isNotNull);
      expect(validarSenhaNova('abcdefgh', 'abcdefgX'), isNotNull);
      expect(validarSenhaNova('abcdefgh', 'abcdefgh'), isNull);
    });
  });

  group('mensagemSenhaProvisoria', () {
    test('com e sem nome', () {
      expect(
        mensagemSenhaProvisoria('Ana', 'k7m2p-q9xab'),
        contains('Olá Ana!'),
      );
      expect(mensagemSenhaProvisoria('', 'k7m2p-q9xab'), startsWith('Olá!'));
      expect(
        mensagemSenhaProvisoria('Ana', 'k7m2p-q9xab'),
        contains('k7m2p-q9xab'),
      );
    });
  });
}
