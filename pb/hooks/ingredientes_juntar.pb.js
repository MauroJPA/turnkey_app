/// <reference path="../pb_data/types.d.ts" />

// POST /api/gc_turnkey/ingredientes/juntar   { origemId, destinoId }
// Ver ingredientes_juntar.js.

routerAdd(
  'POST',
  '/api/gc_turnkey/ingredientes/juntar',
  (e) => {
    const auth = e.auth;
    if (!auth || auth.collection().name !== 'users') {
      throw new ForbiddenError('Autenticação necessária.');
    }
    if (auth.getString('papel') === 'viewer') {
      throw new ForbiddenError('Sem permissão.');
    }
    const body = e.requestInfo().body || {};
    const r = require(`${__hooks}/ingredientes_juntar.js`).juntarIngredientes(
      e.app,
      auth.getString('empresa'),
      String(body.origemId || ''),
      String(body.destinoId || ''),
    );
    return e.json(200, r);
  },
  $apis.requireAuth('users'),
);
