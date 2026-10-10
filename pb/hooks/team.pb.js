/// <reference path="../pb_data/types.d.ts" />

// M6 — gestão de equipa (endpoints privilegiados; as regras de API não deixam
// o cliente mexer em `empresa`/`papel` diretamente — ver guards.pb.js).
//
//   POST  /api/gc_turnkey/team/members         { nome, email, password, papel, papel_personalizado? }
//   PATCH /api/gc_turnkey/team/members/{id}     { papel } ou { papel_personalizado }
//
// Papel personalizado (2.21.0): `papel_personalizado` = id de um
// `papeis_personalizados` da empresa; a pessoa fica com `papel` = o papel base
// dele (é o que o servidor deixa fazer). Escolher um papel normal limpa o
// personalizado. As mesmas regras: o administrador só dá papéis de base Editor
// ou Leitura, e só a quem é Editor ou Leitura.
//
// NOTA: cada handler é autocontido (os handlers correm isolados e não veem
// funções de topo do ficheiro).

routerAdd(
  'POST',
  '/api/gc_turnkey/team/members',
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
    let personalizado = '';
    if (body.papel_personalizado) {
      let pp;
      try {
        pp = e.app.findRecordById('papeis_personalizados', String(body.papel_personalizado));
      } catch (_) {
        throw new BadRequestError('Esse papel já não existe.');
      }
      if (pp.getString('empresa') !== empresaId) throw new BadRequestError('Esse papel já não existe.');
      papel = pp.getString('base');
      personalizado = pp.id;
      if (papelCaller === 'admin' && papel === 'admin') {
        throw new ForbiddenError('Só o proprietário dá papéis com base de administrador.');
      }
    }
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
      u.set('papel_personalizado', personalizado);
      u.set('verified', true);
      u.set('aprovado', true);
      tx.save(u);
      novoId = u.id;
    });

    return e.json(200, { id: novoId });
  },
  $apis.requireAuth('users'),
);

routerAdd(
  'PATCH',
  '/api/gc_turnkey/team/members/{id}',
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
    let novoPapel = body.papel;
    let personalizado = '';
    if (body.papel_personalizado) {
      let pp;
      try {
        pp = e.app.findRecordById('papeis_personalizados', String(body.papel_personalizado));
      } catch (_) {
        throw new BadRequestError('Esse papel já não existe.');
      }
      if (pp.getString('empresa') !== empresaId) throw new BadRequestError('Esse papel já não existe.');
      novoPapel = pp.getString('base');
      personalizado = pp.id;
    }
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
      if (
        papelCaller === 'admin' &&
        papelAtual !== 'editor' &&
        papelAtual !== 'viewer'
      ) {
        throw new ForbiddenError(
          'Só o proprietário pode alterar administradores e proprietários.',
        );
      }
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
      if (personalizado && papelAtual === 'owner') {
        throw new BadRequestError('O proprietário tem sempre acesso total (sem papel personalizado).');
      }
      target.set('papel', novoPapel);
      target.set('papel_personalizado', personalizado);
      tx.save(target);
    });

    return e.json(200, { ok: true });
  },
  $apis.requireAuth('users'),
);
