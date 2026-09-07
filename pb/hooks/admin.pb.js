/// <reference path="../pb_data/types.d.ts" />

// Recalcula em cascata TODAS as receitas e fichas de uma empresa.
// Útil depois de uma importação em massa, ou como botão "Recalcular tudo".
//
//   POST /api/turnkey/admin/recompute   { empresa? }
//
// Regras: superuser, OU owner/admin (e nesse caso só a própria empresa).

routerAdd(
  'POST',
  '/api/turnkey/admin/recompute',
  (e) => {
    const auth = e.auth;
    const isSuper =
      auth && auth.collection() && auth.collection().name === '_superusers';
    let empresaId = (e.requestInfo().body || {}).empresa || '';

    if (!isSuper) {
      if (!auth || auth.collection().name !== 'users') {
        throw new ForbiddenError('Autenticação necessária.');
      }
      const papel = auth.getString('papel');
      if (papel !== 'owner' && papel !== 'admin') {
        throw new ForbiddenError('Precisas de ser administrador.');
      }
      empresaId = auth.getString('empresa');
    }
    if (!empresaId) throw new BadRequestError('empresa em falta.');

    const cascade = require(`${__hooks}/cascade.js`);
    let receitas = 0;
    let fichas = 0;

    e.app.runInTransaction((tx) => {
      const rs = tx.findRecordsByFilter(
        'receitas',
        'empresa = {:e}',
        '',
        0,
        0,
        { e: empresaId },
      );
      for (const r of rs) {
        cascade.runCascade(tx, 'receita', r.id);
        receitas++;
      }
      const fs = tx.findRecordsByFilter(
        'fichas_tecnicas',
        'empresa = {:e}',
        '',
        0,
        0,
        { e: empresaId },
      );
      for (const f of fs) {
        cascade.runCascade(tx, 'ficha', f.id);
        fichas++;
      }
    });

    return e.json(200, { receitas: receitas, fichas: fichas });
  },
  $apis.requireAuth('users', '_superusers'),
);
