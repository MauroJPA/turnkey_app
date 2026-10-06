import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/settings/domain/opcoes_resumo.dart';

void main() {
  group('resumoCustos', () {
    test('com e sem IVA', () {
      expect(
        resumoCustos(cmv: 30, margem: 25, iva: 23),
        'CMV 30% · margem 25% · IVA 23%',
      );
      expect(
        resumoCustos(cmv: 30, margem: 12.5, iva: 0),
        'CMV 30% · margem 12.5%',
      );
    });
  });

  group('resumoAvisos', () {
    test('desligados', () {
      expect(
        resumoAvisos(
          ativo: false,
          hora: '08:00',
          email: true,
          telegram: false,
          semanal: false,
        ),
        'Desligados',
      );
    });

    test('diário por email e Telegram, com semanal', () {
      expect(
        resumoAvisos(
          ativo: true,
          hora: '08:00',
          email: true,
          telegram: true,
          semanal: true,
        ),
        'Resumo diário às 08:00 · semanal ligado — por email e Telegram',
      );
    });

    test('só o semanal ligado', () {
      expect(
        resumoAvisos(
          ativo: false,
          hora: '08:00',
          email: false,
          telegram: true,
          semanal: true,
        ),
        'semanal ligado — por Telegram',
      );
    });

    test('ligado mas sem canal avisa', () {
      expect(
        resumoAvisos(
          ativo: true,
          hora: '08:00',
          email: false,
          telegram: false,
          semanal: false,
        ),
        'Sem email nem Telegram escolhido',
      );
    });
  });

  group('resumoSeguranca', () {
    test('combina backups e 2 passos', () {
      expect(
        resumoSeguranca(backupComProblema: false, doisPassos: true),
        'Backups ok · 2 passos ligado',
      );
      expect(
        resumoSeguranca(backupComProblema: true, doisPassos: false),
        'Backup com problema · 2 passos desligado',
      );
    });

    test('ainda sem dados: texto neutro', () {
      expect(
        resumoSeguranca(backupComProblema: null, doisPassos: null),
        'Backups e acesso com 2 passos',
      );
      expect(
        resumoSeguranca(backupComProblema: false, doisPassos: null),
        'Backups ok',
      );
    });
  });
}
