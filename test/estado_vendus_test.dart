import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/sales/domain/estado_vendus.dart';

void main() {
  final agora = DateTime(2026, 10, 6, 15, 0);

  test('ler a resposta do servidor', () {
    final e = EstadoVendus.fromJson({
      'configurado': true,
      'tentativaEm': '2026-10-06T13:05:00.000Z',
      'okEm': '2026-10-06T12:05:00.000Z',
      'resultado': '3 venda(s) nova(s)',
    });
    expect(e.configurado, isTrue);
    expect(e.okEm, isNotNull);
    expect(e.resultado, '3 venda(s) nova(s)');
    final vazio = EstadoVendus.fromJson({});
    expect(vazio.configurado, isFalse);
    expect(vazio.okEm, isNull);
  });

  test('desatualizado: ligado e sem sincronização boa há mais de 26 h', () {
    EstadoVendus com(DateTime? ok, {bool cfg = true}) =>
        EstadoVendus(configurado: cfg, okEm: ok);
    expect(
      com(agora.subtract(const Duration(hours: 2))).desatualizado(agora),
      isFalse,
    );
    expect(
      com(agora.subtract(const Duration(hours: 27))).desatualizado(agora),
      isTrue,
    );
    expect(com(null).desatualizado(agora), isTrue);
    // sem Vendus configurado nunca avisa
    expect(com(null, cfg: false).desatualizado(agora), isFalse);
  });

  test('pede para sincronizar quando passam mais de 3 horas', () {
    EstadoVendus com(DateTime? ok) => EstadoVendus(configurado: true, okEm: ok);
    expect(
      com(agora.subtract(const Duration(hours: 1))).pedeSincronizar(agora),
      isFalse,
    );
    expect(
      com(agora.subtract(const Duration(hours: 4))).pedeSincronizar(agora),
      isTrue,
    );
    expect(
      const EstadoVendus(configurado: false).pedeSincronizar(agora),
      isFalse,
    );
  });

  test('texto de quando', () {
    EstadoVendus com(DateTime? ok) => EstadoVendus(configurado: true, okEm: ok);
    expect(com(DateTime(2026, 10, 6, 14, 5)).quando(agora), '14:05');
    expect(com(DateTime(2026, 10, 5, 23, 40)).quando(agora), 'ontem 23:40');
    expect(com(DateTime(2026, 10, 1, 9, 0)).quando(agora), '1/10 09:00');
    expect(com(null).quando(agora), 'nunca');
  });
}
