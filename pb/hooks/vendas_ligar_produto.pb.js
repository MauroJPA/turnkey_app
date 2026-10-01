/// <reference path="../pb_data/types.d.ts" />

// POST /api/gc_turnkey/vendas/ligar-produto   { descricao, fichaId }
// Ver vendas_ligar_produto.js.

routerAdd(
  'POST',
  '/api/gc_turnkey/vendas/ligar-produto',
  (e) => {
    const auth = e.auth;
    if (!auth || auth.collection().name !== 'users') {
      throw new ForbiddenError('Autenticação necessária.');
    }
    if (auth.getString('papel') === 'viewer') {
      throw new ForbiddenError('Sem permissão.');
    }
    const body = e.requestInfo().body || {};
    const r = require(`${__hooks}/vendas_ligar_produto.js`).ligarProduto(
      e.app,
      auth.getString('empresa'),
      auth.id,
      String(body.descricao || ''),
      String(body.fichaId || ''),
    );
    return e.json(200, r);
  },
  $apis.requireAuth('users'),
);
