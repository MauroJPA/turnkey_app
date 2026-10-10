import 'package:flutter_test/flutter_test.dart';
import 'package:gc_turnkey/src/core/auth/permissions.dart';
import 'package:gc_turnkey/src/features/navigation/domain/nav_config.dart';
import 'package:gc_turnkey/src/features/navigation/domain/papel_personalizado.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  const balcao = PapelPersonalizado(
    id: 'b',
    nome: 'Balcão',
    base: Papel.editor,
    acesso: {'financeiro': NivelAcesso.oculto, 'receitas': NivelAcesso.ver},
  );
  // a empresa mudou a matriz do Editor: Compras só ver
  const config = NavConfig(
    acesso: {
      'editor': {'compras': NivelAcesso.ver},
    },
  );

  test('o papel personalizado manda nas páginas ajustadas e herda o resto', () {
    final c = config.comMeu(balcao);
    expect(c.nivel(Papel.editor, 'financeiro'), NivelAcesso.oculto);
    expect(c.nivel(Papel.editor, 'receitas'), NivelAcesso.ver);
    // herda a matriz da empresa para o Editor
    expect(c.nivel(Papel.editor, 'compras'), NivelAcesso.ver);
    // e o valor por omissão do Editor
    expect(c.nivel(Papel.editor, 'producao'), NivelAcesso.editar);
    expect(c.acessivel(Papel.editor, 'financeiro'), isFalse);
  });

  test('só vale para o seu papel base; o proprietário tem sempre tudo', () {
    final c = config.comMeu(balcao);
    expect(c.nivel(Papel.viewer, 'receitas'), NivelAcesso.ver);
    expect(c.nivel(Papel.admin, 'financeiro'), NivelAcesso.editar);
    expect(c.nivel(Papel.owner, 'financeiro'), NivelAcesso.editar);
    // a matriz "pura" não muda
    expect(c.nivelBase(Papel.editor, 'financeiro'), NivelAcesso.editar);
  });

  test('com base Leitura nunca passa de "Só ver"', () {
    const contabilista = PapelPersonalizado(
      id: 'c',
      nome: 'Contabilista',
      base: Papel.viewer,
      acesso: {
        'financeiro': NivelAcesso.editar,
        'producao': NivelAcesso.oculto,
      },
    );
    final c = NavConfig.vazia.comMeu(contabilista);
    expect(c.nivel(Papel.viewer, 'financeiro'), NivelAcesso.ver);
    expect(c.nivel(Papel.viewer, 'producao'), NivelAcesso.oculto);
    // Pessoas: oculto para a Leitura por omissão — herda
    expect(c.nivel(Papel.viewer, 'pessoas'), NivelAcesso.oculto);
  });

  test('comNivel: igual ao papel base deixa de ser um ajuste', () {
    final a = balcao.comNivel('receitas', NivelAcesso.editar, config);
    expect(a.acesso.containsKey('receitas'), isFalse);
    expect(a.nAjustes, 1);
    final b = a.comNivel('compras', NivelAcesso.oculto, config);
    expect(b.acesso['compras'], NivelAcesso.oculto);
    // compras no Editor desta empresa é "ver": voltar a "ver" tira o ajuste
    expect(b.comNivel('compras', NivelAcesso.ver, config).acesso, {
      'financeiro': NivelAcesso.oculto,
    });
    expect(balcao.acessoJson(), {'financeiro': 'oculto', 'receitas': 'ver'});
  });

  test('fromRecord: tolerante e nunca dá o proprietário', () {
    final r = RecordModel({
      'id': 'x',
      'nome': 'Estranho',
      'base': 'owner',
      'acesso': {
        'financeiro': 'ver',
        'naoexiste': 'editar',
        'receitas': 'lixo',
      },
    });
    final p = PapelPersonalizado.fromRecord(r);
    expect(p.base, Papel.viewer);
    expect(p.acesso, {'financeiro': NivelAcesso.ver});
  });

  test(
    'papeisQuePossoDar: o administrador não dá os de base Administrador',
    () {
      const gerente = PapelPersonalizado(
        id: 'g',
        nome: 'Gerente',
        base: Papel.admin,
      );
      final todos = [balcao, gerente];
      expect(papeisQuePossoDar(Papel.owner, todos).map((p) => p.id), [
        'b',
        'g',
      ]);
      expect(papeisQuePossoDar(Papel.admin, todos).map((p) => p.id), ['b']);
    },
  );
}
