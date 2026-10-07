import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/features/settings/domain/opcoes_resumo.dart';
import 'package:gc_turnkey/src/features/settings/domain/vigia.dart';

Map<String, dynamic> _achado(
  String id,
  String gravidade, {
  bool aceite = false,
  int desde = 1800000000,
}) => {
  'id': id,
  'gravidade': gravidade,
  'categoria': 'acesso',
  'titulo': 'Título $id',
  'detalhe': 'Detalhe',
  'fazer': 'Faz isto',
  'desde': desde,
  'vezes': 2,
  'itens': ['alterado: hooks/a.js'],
  'aceite': aceite,
};

Map<String, dynamic> _json(
  List<Map<String, dynamic>> achados, {
  bool parado = false,
}) => {
  'operador': true,
  'instalado': true,
  'estado': 'ok',
  'pontuacao': 12,
  'quando': 1800000600,
  'parado': parado,
  'achados': achados,
  'verificacoes': {
    'ssh': {'ok': true, 'quando': 1},
    'rede': {'ok': false, 'quando': 1},
  },
  'notas': ['Primeira ronda'],
};

void main() {
  group('EstadoVigia.fromJson', () {
    test('quem não é o dono ou sem vigia instalado: vazio', () {
      expect(EstadoVigia.fromJson({'operador': false}).instalado, isFalse);
      final nao = EstadoVigia.fromJson({'operador': true, 'instalado': false});
      expect(nao.instalado, isFalse);
      expect(nao.resumo, 'Vigia ainda não instalado');
    });

    test('lê os alertas e as verificações', () {
      final e = EstadoVigia.fromJson(
        _json([_achado('a', 'critico'), _achado('b', 'info')]),
      );
      expect(e.instalado, isTrue);
      expect(e.achados.length, 2);
      expect(e.achados.first.gravidade, GravidadeVigia.critico);
      expect(e.achados.first.itens, ['alterado: hooks/a.js']);
      expect(e.achados.first.desde, isNotNull);
      expect(e.verificacoes, 2);
      expect(e.verificacoesComErro, 1);
      expect(e.notas, ['Primeira ronda']);
    });

    test('gravidade desconhecida vira "para saber"', () {
      expect(GravidadeVigia.fromApi('xpto'), GravidadeVigia.info);
    });
  });

  group('nível e resumo', () {
    test('sem alertas: tudo calmo', () {
      final e = EstadoVigia.fromJson(_json([]));
      expect(e.nivel, GravidadeVigia.info);
      expect(e.resumo, 'Tudo calmo');
      expect(e.ativos, isEmpty);
    });

    test('só informação não pede ação', () {
      final e = EstadoVigia.fromJson(_json([_achado('i', 'info')]));
      expect(e.nivel, GravidadeVigia.info);
      expect(e.paraSaber.length, 1);
      expect(e.resumo, 'Tudo calmo');
    });

    test('um de atenção e um crítico', () {
      final e = EstadoVigia.fromJson(
        _json([_achado('a', 'atencao'), _achado('b', 'critico')]),
      );
      expect(e.nivel, GravidadeVigia.critico);
      expect(e.criticos, 1);
      expect(e.resumo, '2 alertas a ver (1 urgente)');
    });

    test('alerta aceite deixa de contar e fica "a aprender"', () {
      final e = EstadoVigia.fromJson(
        _json([_achado('a', 'critico', aceite: true)]),
      );
      expect(e.ativos, isEmpty);
      expect(e.aAprender.length, 1);
      expect(e.nivel, GravidadeVigia.info);
    });

    test('vigia parado conta como atenção', () {
      final e = EstadoVigia.fromJson(_json([], parado: true));
      expect(e.nivel, GravidadeVigia.atencao);
      expect(e.resumo, 'O vigia parou de correr');
    });

    test('possível intrusão', () {
      final e = EstadoVigia.fromJson(
        _json([_achado('incidente', 'critico'), _achado('x', 'critico')]),
      );
      expect(e.haIncidente, isTrue);
      expect(e.resumo, startsWith('POSSÍVEL INTRUSÃO'));
    });
  });

  group('textoHa', () {
    final agora = DateTime(2026, 10, 7, 12);
    test('escalas', () {
      expect(textoHa(null, agora), '');
      expect(
        textoHa(agora.subtract(const Duration(seconds: 30)), agora),
        'agora mesmo',
      );
      expect(
        textoHa(agora.subtract(const Duration(minutes: 7)), agora),
        'há 7 min',
      );
      expect(
        textoHa(agora.subtract(const Duration(hours: 5)), agora),
        'há 5 h',
      );
      expect(
        textoHa(agora.subtract(const Duration(days: 4)), agora),
        'há 4 dias',
      );
    });
  });

  group('resumo nas Opções', () {
    test('o estado do vigia entra no resumo da Segurança', () {
      expect(
        resumoSeguranca(
          backupComProblema: false,
          doisPassos: true,
          vigia: 'tudo calmo',
        ),
        'Vigia: tudo calmo · Backups ok · 2 passos ligado',
      );
      expect(
        resumoSeguranca(backupComProblema: false, doisPassos: true),
        'Backups ok · 2 passos ligado',
      );
    });
  });
}
