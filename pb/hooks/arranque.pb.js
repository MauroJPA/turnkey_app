/// <reference path="../pb_data/types.d.ts" />

// "Primeiros passos" no Início: o que falta configurar para a app estar a 100 %.
//
//   GET /api/gc_turnkey/arranque -> { passos: [{ chave, feito, detalhe }], feitos, total }
//
// Só owner/admin da empresa. Só devolve números e estados (nada de conteúdo,
// chaves ou caminhos). Os passos "backups" e "vigia" são do servidor e o
// "vigia" só aparece ao dono do servidor (operador).
// NOTA: cada handler corre isolado — usa require() para o resto.

routerAdd('GET', '/api/gc_turnkey/arranque', (e) => {
  const auth = e.auth;
  if (!auth) throw new UnauthorizedError('Autenticação necessária.');
  const papel = auth.getString('papel');
  if (papel !== 'owner' && papel !== 'admin') {
    throw new ForbiddenError('Só a administração vê os primeiros passos.');
  }
  const empresaId = auth.getString('empresa');
  if (!empresaId) throw new ForbiddenError('Sem empresa.');

  const core = require(`${__hooks}/arranque_core.js`);
  const contagens = core.contar(e.app, empresaId);

  const extra = {};
  try {
    const dados = String(e.app.dataDir());
    const est = require(`${__hooks}/backups_core.js`).lerEstadoJson(dados + '/backup_externo.json');
    extra.backupExterno = !!(est && est.ok === true);
  } catch (_) {
    extra.backupExterno = false;
  }
  try {
    const { ehOperador } = require(`${__hooks}/operador.js`);
    if (ehOperador(e.app, auth)) {
      const v = require(`${__hooks}/vigia_core.js`).estado(e.app);
      extra.vigia = v.instalado !== false;
    }
  } catch (_) {}
  try {
    extra.ia = !!($os.getenv('GEMINI_API_KEY') || $os.getenv('GOOGLE_API_KEY') || $os.getenv('ANTHROPIC_API_KEY'));
  } catch (_) {}

  const passos = core.passos(contagens, extra);
  const feitos = passos.filter((p) => p.feito).length;
  return e.json(200, { passos: passos, feitos: feitos, total: passos.length });
});
