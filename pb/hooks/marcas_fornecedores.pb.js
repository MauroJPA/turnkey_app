/// <reference path="../pb_data/types.d.ts" />

// POST /api/gc_turnkey/marcas-fornecedores/juntar
//   { tipo: 'marca' | 'fornecedor', valores: string[], destino: string }
// Junta vários nomes de marca/fornecedor (escritos ligeiramente diferentes)
// num só, em todos os registos da empresa — ver marcas_fornecedores.js.
// Só proprietário/administrador: pode alterar dezenas de registos de uma vez.

routerAdd(
  'POST',
  '/api/gc_turnkey/marcas-fornecedores/juntar',
  (e) => {
    const auth = e.auth;
    if (!auth || auth.collection().name !== 'users') {
      throw new ForbiddenError('Autenticação necessária.');
    }
    const papel = auth.getString('papel');
    if (papel !== 'owner' && papel !== 'admin') {
      throw new ForbiddenError('Só o proprietário ou o administrador juntam marcas/fornecedores.');
    }
    const body = e.requestInfo().body || {};
    const r = require(`${__hooks}/marcas_fornecedores.js`).juntarMarcasFornecedores(
      e.app,
      auth.getString('empresa'),
      String(body.tipo || ''),
      Array.isArray(body.valores) ? body.valores : [],
      String(body.destino || ''),
    );
    return e.json(200, r);
  },
  $apis.requireAuth('users'),
);
