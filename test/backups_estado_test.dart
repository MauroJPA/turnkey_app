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

  group('disco e testes (1.103.0)', () {
    EstadoBackups com(Map<String, dynamic> extra) => EstadoBackups.fromJson({
      'local': {
        'total': 7,
        'ultimo': {
          'nome': 'b.zip',
          'tamanho': 1000,
          'quando': agora.subtract(const Duration(hours: 9)).toIso8601String(),
        },
      },
      'externo': {'estado': 'desconhecido'},
      ...extra,
    });

    const gb = 1024 * 1024;

    test('disco com folga não é problema', () {
      final e = com({
        'disco': {
          'dados': {'livreKb': 100 * gb, 'totalKb': 200 * gb},
        },
      });
      expect(e.discoBaixo, isFalse);
      expect(e.problema(agora), isFalse);
    });

    test('menos de 15 % livre é problema', () {
      final e = com({
        'disco': {
          'dados': {'livreKb': 20 * gb, 'totalKb': 200 * gb},
        },
      });
      expect(e.discoBaixo, isTrue);
      expect(e.problema(agora), isTrue);
      expect(e.avisos(agora).join(' '), contains('pouco espaço'));
    });

    test('menos de 2 GB livres é problema mesmo num disco pequeno', () {
      final e = com({
        'disco': {
          'dados': {'livreKb': 1 * gb, 'totalKb': 4 * gb},
        },
      });
      expect(e.discoBaixo, isTrue);
    });

    test('o disco dos backups conta quando é outro disco', () {
      final e = com({
        'disco': {
          'dados': {'livreKb': 100 * gb, 'totalKb': 200 * gb},
          'backups': {'livreKb': 1 * gb, 'totalKb': 500 * gb},
        },
      });
      expect(e.discoBaixo, isTrue);
    });

    test('teste de integridade falhado é problema com a mensagem', () {
      final e = com({
        'integridade': {
          'ok': false,
          'quando': agora.toIso8601String(),
          'mensagem': 'O backup parece estar estragado',
        },
      });
      expect(e.integridadeFalhou, isTrue);
      expect(e.problema(agora), isTrue);
      expect(e.avisos(agora).join(' '), contains('estragado'));
    });

    test('teste de restauro falhado é problema; ok não é', () {
      expect(
        com({
          'restauro': {'ok': false, 'mensagem': 'não arrancou'},
        }).problema(agora),
        isTrue,
      );
      expect(
        com({
          'restauro': {'ok': true, 'segundos': 14},
        }).problema(agora),
        isFalse,
      );
    });

    test('sem testes nem disco (null) não é problema', () {
      final e = com({
        'disco': {'dados': null},
        'integridade': null,
      });
      expect(e.problema(agora), isFalse);
    });
  });
}
