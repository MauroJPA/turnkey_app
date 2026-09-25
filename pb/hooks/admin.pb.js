/// <reference path="../pb_data/types.d.ts" />

// Recalcula em cascata TODAS as receitas e fichas de uma empresa.
// Útil depois de uma importação em massa, ou como botão "Recalcular tudo".
//
//   POST /api/gc_turnkey/admin/recompute   { empresa? }
//
// Regras: superuser, OU owner/admin (e nesse caso só a própria empresa).

routerAdd(
  'POST',
  '/api/gc_turnkey/admin/recompute',
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
    let ingredientes = 0;
    let receitas = 0;
    let fichas = 0;

    e.app.runInTransaction((tx) => {
      // 1) custo/grama de cada ingrediente (e cascata para quem o usa)
      const ings = tx.findRecordsByFilter(
        'ingredientes',
        'empresa = {:e} && deletado != true',
        '',
        0,
        0,
        { e: empresaId },
      );
      for (const ing of ings) {
        cascade.runCascade(tx, 'ingrediente', ing.id);
        ingredientes++;
      }

      // 2) garante que todas as receitas ficam recalculadas
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

    return e.json(200, {
      ingredientes: ingredientes,
      receitas: receitas,
      fichas: fichas,
    });
  },
  $apis.requireAuth('users', '_superusers'),
);

// Religa ingredientes-espelho órfãos à respetiva receita (por nome), define
// `publicar_como_ingrediente` e recalcula. Necessário após a migração do
// meu_app_ia, onde a receita e o "ingrediente de fabrico próprio" vieram desligados.
//
//   POST /api/gc_turnkey/admin/relink-espelhos   { empresa? }
routerAdd(
  'POST',
  '/api/gc_turnkey/admin/relink-espelhos',
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
    let ligados = 0;

    e.app.runInTransaction((tx) => {
      // ingredientes de fabrico próprio sem receita_espelho
      const orfaos = tx.findRecordsByFilter(
        'ingredientes',
        "empresa = {:e} && receita_espelho = '' && " +
          "(origem = 'fabrico_proprio' )",
        '',
        0,
        0,
        { e: empresaId },
      );
      for (const ing of orfaos) {
        const nome = ing.getString('nome');
        const matches = tx.findRecordsByFilter(
          'receitas',
          'empresa = {:e} && nome = {:n}',
          '',
          1,
          0,
          { e: empresaId, n: nome },
        );
        if (matches.length === 0) continue;
        const receita = matches[0];

        ing.set('receita_espelho', receita.id);
        ing.set('origem', 'fabrico_proprio');
        tx.save(ing);

        if (!receita.getBool('publicar_como_ingrediente')) {
          receita.set('publicar_como_ingrediente', true);
          tx.save(receita);
        }
        ligados++;
      }

      // recalcula tudo para propagar às fichas
      const rs = tx.findRecordsByFilter(
        'receitas',
        'empresa = {:e}',
        '',
        0,
        0,
        { e: empresaId },
      );
      for (const r of rs) cascade.runCascade(tx, 'receita', r.id);
      const fs = tx.findRecordsByFilter(
        'fichas_tecnicas',
        'empresa = {:e}',
        '',
        0,
        0,
        { e: empresaId },
      );
      for (const f of fs) cascade.runCascade(tx, 'ficha', f.id);
    });

    return e.json(200, { ligados: ligados });
  },
  $apis.requireAuth('users', '_superusers'),
);
