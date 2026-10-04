import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/core/auth/permissions.dart';
import 'package:gc_turnkey/src/features/navigation/domain/nav_config.dart';
import 'package:gc_turnkey/src/features/navigation/domain/nav_prefs.dart';
import 'package:gc_turnkey/src/features/navigation/domain/pagina_app.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  group('paginaDaRota', () {
    test('a rota mais específica ganha', () {
      expect(paginaDaRota('/opcoes/equipa')?.chave, 'equipa');
      expect(paginaDaRota('/opcoes/formatos')?.chave, 'configuracoes');
      expect(paginaDaRota('/opcoes/navegacao')?.chave, 'configuracoes');
      expect(paginaDaRota('/opcoes')?.chave, 'configuracoes');
      expect(paginaDaRota('/financeiro/dre')?.chave, 'financeiro');
      expect(paginaDaRota('/financeiro/custos-fixos')?.chave, 'custosFixos');
      expect(paginaDaRota('/vendas/analise')?.chave, 'vendas');
      expect(paginaDaRota('/receitas/abc123')?.chave, 'receitas');
    });

    test('Início e rotas desconhecidas não têm página', () {
      expect(paginaDaRota('/'), isNull);
      expect(paginaDaRota('/receitasx'), isNull);
    });

    test('chaves únicas', () {
      final chaves = paginasApp.map((p) => p.chave).toList();
      expect(chaves.toSet().length, chaves.length);
    });
  });

  group('paginaDaRota', () {
    test('a Agenda faz parte da Produção', () {
      expect(paginaDaRota('/produzir')?.chave, 'producao');
      expect(paginaDaRota('/produzir/agendar')?.chave, 'producao');
      expect(paginaDaRota('/agenda')?.chave, 'producao');
      expect(paginaDaRota('/agenda/abc')?.chave, 'producao');
    });

    test('as secções do Inventário e as fichas', () {
      expect(paginaDaRota('/inventario/limpeza')?.chave, 'inventario');
      expect(paginaDaRota('/fichas-tecnicas/x/informacao')?.chave, 'fichas');
      expect(paginaDaRota('/ingredientes'), isNull); // só redireciona
    });
  });

  group('NavConfig', () {
    test('valores por omissão iguais ao comportamento anterior', () {
      const c = NavConfig();
      expect(c.nivel(Papel.admin, 'vendas'), NivelAcesso.editar);
      expect(c.nivel(Papel.editor, 'vendas'), NivelAcesso.editar);
      expect(c.nivel(Papel.editor, 'configuracoes'), NivelAcesso.ver);
      expect(c.nivel(Papel.editor, 'equipa'), NivelAcesso.ver);
      expect(c.nivel(Papel.viewer, 'vendas'), NivelAcesso.ver);
      expect(c.rodape, rodapePorOmissao);
    });

    test('comNivel guarda só o que difere e o dono nunca perde acesso', () {
      var c = const NavConfig();
      c = c.comNivel(Papel.editor, 'financeiro', NivelAcesso.oculto);
      c = c.comNivel(Papel.owner, 'financeiro', NivelAcesso.oculto);
      expect(c.nivel(Papel.editor, 'financeiro'), NivelAcesso.oculto);
      expect(c.acessivel(Papel.editor, 'financeiro'), isFalse);
      expect(c.nivel(Papel.owner, 'financeiro'), NivelAcesso.editar);
      expect(c.acessoJson(), {
        'editor': {'financeiro': 'oculto'},
        'owner': {'financeiro': 'oculto'},
      });

      c = c.comNivel(Papel.editor, 'financeiro', NivelAcesso.editar);
      expect(c.acessoJson().containsKey('editor'), isFalse);
    });

    test('rodapePara tira as páginas ocultas do papel', () {
      final c = const NavConfig().comNivel(
        Papel.viewer,
        'compras',
        NivelAcesso.oculto,
      );
      final viewer = c.rodapePara(Papel.viewer).map((p) => p.chave).toList();
      expect(viewer, ['producao', 'contagem', 'inventario']);
      expect(c.rodapePara(Papel.admin).length, 4);
    });

    test('fromRecord ignora lixo e mantém o resto', () {
      final r = RecordModel.fromJson({
        'id': 'x1',
        'rodape': ['vendas', 'nao-existe', 42, 'contagem'],
        'acesso': {
          'editor': {
            'vendas': 'oculto',
            'nao-existe': 'oculto',
            'contagem': 'banana',
          },
          'viewer': 'lixo',
        },
      });
      final c = NavConfig.fromRecord(r);
      expect(c.id, 'x1');
      expect(c.rodape, ['vendas', 'contagem']);
      expect(c.nivel(Papel.editor, 'vendas'), NivelAcesso.oculto);
      expect(c.nivel(Papel.editor, 'contagem'), NivelAcesso.editar);
    });

    test('rodapé vazio ou em falta volta ao original', () {
      final vazio = NavConfig.fromRecord(
        RecordModel.fromJson({'id': 'x', 'rodape': <String>[]}),
      );
      expect(vazio.rodape, rodapePorOmissao);
      final semCampo = NavConfig.fromRecord(RecordModel.fromJson({'id': 'x'}));
      expect(semCampo.rodape, rodapePorOmissao);
    });
  });

  group('NavPrefs', () {
    test('corDeHex', () {
      expect(corDeHex('#E53935'), const Color(0xFFE53935));
      expect(corDeHex('E53935'), const Color(0xFFE53935));
      expect(corDeHex('#zzz'), isNull);
      expect(corDeHex(null), isNull);
    });

    test('esconder e cores', () {
      var p = const NavPrefs();
      p = p.comOculto('vendas', true).comCor('vendas', '#43A047');
      expect(p.escondida('vendas'), isTrue);
      expect(p.cor('vendas'), const Color(0xFF43A047));
      p = p.comOculto('vendas', false).comCor('vendas', '');
      expect(p.escondida('vendas'), isFalse);
      expect(p.cor('vendas'), isNull);
      expect(p.toBody(), {'oculto': <String>[], 'cores': <String, String>{}});
    });

    test('fromRecord descarta cores inválidas', () {
      final p = NavPrefs.fromRecord(RecordModel.fromJson({
        'id': 'p1',
        'oculto': ['vendas', 3],
        'cores': {'vendas': '#00897B', 'faturas': 'azul'},
      }));
      expect(p.oculto, {'vendas'});
      expect(p.cores, {'vendas': '#00897B'});
    });
  });
}
