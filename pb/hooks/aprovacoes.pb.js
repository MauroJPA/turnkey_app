/// <reference path="../pb_data/types.d.ts" />

// Aprovação de contas novas dentro da app (sem usar o painel /_/).
//
//   GET  /api/gc_turnkey/aprovacoes                -> { operador, pendentes: [...] }
//   POST /api/gc_turnkey/aprovacoes/{id}/aprovar   -> aprova a conta
//   POST /api/gc_turnkey/aprovacoes/{id}/recusar   -> apaga a conta (só se ainda por aprovar)
//
// Só o "operador da plataforma" (ver operador.js) vê e decide; os outros
// recebem { operador: false } sem dados.
// NOTA: cada handler corre isolado — por isso usa require() para o resto.

routerAdd('GET', '/api/gc_turnkey/aprovacoes', (e) => {
  if (!e.auth) throw new UnauthorizedError('Autenticação necessária.');
  const { ehOperador } = require(`${__hooks}/operador.js`);
  if (!ehOperador(e.app, e.auth)) {
    return e.json(200, { operador: false, pendentes: [] });
  }
  const recs = e.app.findRecordsByFilter('users', 'aprovado != true', '-created', 100, 0);
  return e.json(200, {
    operador: true,
    pendentes: recs.map((r) => ({
      id: r.id,
      email: r.getString('email'),
      nome: r.getString('name'),
      criada: r.getString('created'),
    })),
  });
});

routerAdd('POST', '/api/gc_turnkey/aprovacoes/{id}/aprovar', (e) => {
  if (!e.auth) throw new UnauthorizedError('Autenticação necessária.');
  const { ehOperador } = require(`${__hooks}/operador.js`);
  if (!ehOperador(e.app, e.auth)) throw new ForbiddenError('Só o operador da plataforma aprova contas.');
  let u;
  try {
    u = e.app.findRecordById('users', e.request.pathValue('id'));
  } catch (_) {
    throw new NotFoundError('Conta não encontrada.');
  }
  u.set('aprovado', true);
  e.app.save(u);
  console.log('[aprovacoes] aprovada a conta ' + u.id + ' por ' + e.auth.id);
  return e.json(200, { ok: true });
});

routerAdd('POST', '/api/gc_turnkey/aprovacoes/{id}/recusar', (e) => {
  if (!e.auth) throw new UnauthorizedError('Autenticação necessária.');
  const { ehOperador } = require(`${__hooks}/operador.js`);
  if (!ehOperador(e.app, e.auth)) throw new ForbiddenError('Só o operador da plataforma recusa contas.');
  let u;
  try {
    u = e.app.findRecordById('users', e.request.pathValue('id'));
  } catch (_) {
    throw new NotFoundError('Conta não encontrada.');
  }
  if (u.getBool('aprovado')) {
    throw new BadRequestError('Esta conta já está aprovada.');
  }
  e.app.delete(u);
  console.log('[aprovacoes] recusada (apagada) a conta ' + u.id + ' por ' + e.auth.id);
  return e.json(200, { ok: true });
});
