/// <reference path="../pb_data/types.d.ts" />

// M6 — gestão de equipa (endpoints privilegiados; as regras de API não deixam
// o cliente mexer em `empresa`/`papel` diretamente — ver guards.pb.js).
//
//   POST  /api/turnkey/team/members         { nome, email, password, papel }
//   PATCH /api/turnkey/team/members/{id}     { papel }
//
// NOTA: cada handler é autocontido (os handlers correm isolados e não veem
// funções de topo do ficheiro).

routerAdd(
  'POST',
  '/api/turnkey/team/members',
  (e) => {
    const caller = e.auth;
    if (!caller || caller.collection().name !== 'users') {
      throw new ForbiddenError('Autenticação necessária.');
    }
    const empresaId = caller.getString('empresa');
    const papelCaller = caller.getString('papel');
    if (!empresaId || (papelCaller !== 'owner' && papelCaller !== 'admin')) {
      throw new ForbiddenError('Precisas de ser administrador da empresa.');
    }

    const body = e.requestInfo().body || {};
    const email = (body.email || '').toString().trim().toLowerCase();
    const password = (body.password || '').toString();
    const nome = (body.nome || '').toString().trim();
    let papel = ['admin', 'editor', 'viewer'].includes(body.papel)
      ? body.papel
      : 'viewer';
    if (papelCaller === 'admin' && papel === 'admin') papel = 'editor';

    if (!email || password.length < 8) {
      throw new BadRequestError(
        'Email e palavra-passe (mín. 8) obrigatórios.',
      );
    }

    let novoId = '';
    e.app.runInTransaction((tx) => {
      const u = new Record(tx.findCollectionByNameOrId('users'));
      u.set('email', email);
      u.set('emailVisibility', true);
      u.setPassword(password);
      u.set('nome', nome);
      u.set('empresa', empresaId);
      u.set('papel', papel);
      u.set('verified', true);
      tx.save(u);
      novoId = u.id;
    });

    return e.json(200, { id: novoId });
  },
  $apis.requireAuth('users'),
);

routerAdd(
  'PATCH',
  '/api/turnkey/team/members/{id}',
  (e) => {
    const caller = e.auth;
    if (!caller || caller.collection().name !== 'users') {
      throw new ForbiddenError('Autenticação necessária.');
    }
    const empresaId = caller.getString('empresa');
    const papelCaller = caller.getString('papel');
    if (!empresaId || (papelCaller !== 'owner' && papelCaller !== 'admin')) {
      throw new ForbiddenError('Precisas de ser administrador da empresa.');
    }

    const targetId = e.request.pathValue('id');
    const body = e.requestInfo().body || {};
    const novoPapel = body.papel;
    if (!['owner', 'admin', 'editor', 'viewer'].includes(novoPapel)) {
      throw new BadRequestError('Papel inválido.');
    }
    if (
      papelCaller === 'admin' &&
      (novoPapel === 'owner' || novoPapel === 'admin')
    ) {
      throw new ForbiddenError('Só o proprietário pode definir admins.');
    }

    e.app.runInTransaction((tx) => {
      const target = tx.findRecordById('users', targetId);
      if (target.getString('empresa') !== empresaId) {
        throw new ForbiddenError('Utilizador de outra empresa.');
      }
      const papelAtual = target.getString('papel');
      if (papelAtual === 'owner' && novoPapel !== 'owner') {
        const owners = tx.findRecordsByFilter(
          'users',
          "empresa = {:e} && papel = 'owner'",
          '',
          0,
          0,
          { e: empresaId },
        );
        if (owners.length <= 1) {
          throw new BadRequestError(
            'A empresa tem de ter pelo menos um proprietário.',
          );
        }
      }
      target.set('papel', novoPapel);
      tx.save(target);
    });

    return e.json(200, { ok: true });
  },
  $apis.requireAuth('users'),
);
