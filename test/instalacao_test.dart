import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/core/device/instalacao.dart';

void main() {
  test('lê o estado que a página devolve', () {
    final e = EstadoInstalacao.fromJson(
      '{"instalada":false,"podeInstalar":true,"ios":false}',
    );
    expect(e.podeInstalar, isTrue);
    expect(e.instalada, isFalse);
    expect(e.oferecer, isTrue);
  });

  test(
    'só se oferece quando ainda não está instalada e há maneira de a instalar',
    () {
      expect(
        const EstadoInstalacao(podeInstalar: true, instalada: true).oferecer,
        isFalse,
      );
      expect(const EstadoInstalacao().oferecer, isFalse);
      expect(const EstadoInstalacao(ios: true).oferecer, isTrue);
      expect(
        const EstadoInstalacao(ios: true, instalada: true).oferecer,
        isFalse,
      );
    },
  );

  test('texto estragado ou em falta nunca oferece nada', () {
    for (final t in [
      null,
      '',
      'não é json',
      '[]',
      '"x"',
      '{"podeInstalar":"sim"}',
    ]) {
      expect(EstadoInstalacao.fromJson(t).oferecer, isFalse, reason: '$t');
    }
  });

  test('as instruções do iPhone dizem onde tocar', () {
    expect(instrucoesInstalarIos, contains('Partilhar'));
    expect(instrucoesInstalarIos, contains('Adicionar ao ecrã principal'));
  });
}
