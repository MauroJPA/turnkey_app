import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/settings/data/aprovacoes_repository.dart';

void main() {
  test('lê uma conta por aprovar do servidor', () {
    final c = ContaPendente.fromJson({
      'id': 'u1',
      'email': 'nova@exemplo.pt',
      'nome': 'Ana',
      'criada': '2026-10-05 22:14:41.230Z',
    });
    expect(c.id, 'u1');
    expect(c.email, 'nova@exemplo.pt');
    expect(c.nome, 'Ana');
    expect(c.criada!.year, 2026);
  });

  test('tolera campos em falta', () {
    final c = ContaPendente.fromJson({});
    expect(c.id, '');
    expect(c.nome, '');
    expect(c.criada, isNull);
  });

  test('sem operador por omissão', () {
    const a = Aprovacoes();
    expect(a.operador, isFalse);
    expect(a.pendentes, isEmpty);
  });
}
