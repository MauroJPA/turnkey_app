import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/settings/data/backups_repository.dart';

void main() {
  final agora = DateTime.utc(2026, 10, 6, 12);

  EstadoBackups estado({
    int horasLocal = 9,
    String externo = 'ok',
    int horasExterno = 8,
    int total = 7,
    String msg = '',
  }) => EstadoBackups.fromJson({
    'local': {
      'total': total,
      'ultimo': total == 0
          ? null
          : {
              'nome': 'backup.zip',
              'tamanho': 2048,
              'quando': agora
                  .subtract(Duration(hours: horasLocal))
                  .toIso8601String(),
            },
    },
    'externo': {
      'estado': externo,
      'quando': externo == 'desconhecido'
          ? ''
          : agora.subtract(Duration(hours: horasExterno)).toIso8601String(),
      'mensagem': msg,
    },
  });

  test('tudo em dia não é problema', () {
    final e = estado();
    expect(e.problema(agora), isFalse);
    expect(e.avisos(agora), isEmpty);
    expect(e.ultimoNome, 'backup.zip');
    expect(e.ultimoTamanho, 2048);
  });

  test('backup local atrasado (mais de 30 h) é problema', () {
    final e = estado(horasLocal: 40);
    expect(e.problema(agora), isTrue);
    expect(e.avisos(agora).single, contains('40 h'));
  });

  test('sem nenhum backup é problema', () {
    final e = estado(total: 0);
    expect(e.problema(agora), isTrue);
    expect(e.avisos(agora).first, contains('Ainda não há'));
  });

  test('a cópia externa a falhar é problema e mostra a mensagem', () {
    final e = estado(externo: 'falha', msg: 'rclone falhou');
    expect(e.problema(agora), isTrue);
    expect(e.avisos(agora).join(' '), contains('rclone falhou'));
  });

  test('cópia externa ok mas velha é problema', () {
    expect(estado(horasExterno: 50).problema(agora), isTrue);
  });

  test(
    'cópia externa desconhecida não é problema (pode nem estar instalada)',
    () {
      final e = estado(externo: 'desconhecido');
      expect(e.problema(agora), isFalse);
    },
  );

  test('tolera resposta vazia', () {
    final e = EstadoBackups.fromJson({});
    expect(e.localTotal, 0);
    expect(e.problema(agora), isTrue);
  });
}
