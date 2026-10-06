/// <reference path="../pb_data/types.d.ts" />

// Gestão de acessos da equipa (complementa team.pb.js):
//
//   POST   /api/gc_turnkey/team/members/{id}/senha  → { senha }   repor a palavra-passe
//   DELETE /api/gc_turnkey/team/members/{id}                      remover da equipa
//   POST   /api/gc_turnkey/conta/senha   { senha }                escolher a nova (depois da provisória)
//
// NOTA: cada handler é autocontido (os handlers correm isolados e não veem
// funções de topo do ficheiro).

// --- Repor a palavra-passe de alguém da equipa (esqueceu-se) ----------------
// Gera uma palavra-passe PROVISÓRIA (mostrada uma só vez a quem a repôs),
// fecha as sessões abertas dessa conta e obriga a pessoa a escolher uma nova
// na próxima entrada (`users.senha_provisoria`). O proprietário repõe a de
// qualquer pessoa (menos a própria); o administrador só a de Editor/Leitura.
routerAdd(
  'POST',
  '/api/gc_turnkey/team/members/{id}/senha',
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
    if (targetId === caller.id) {
      throw new BadRequestError('A tua própria palavra-passe não se repõe aqui.');
    }

    // sem caracteres que se confundem (0/o, 1/l/i)
    const alfabeto = 'abcdefghjkmnpqrstuvwxyz23456789';
    let senha = '';
    e.app.runInTransaction((tx) => {
      const target = tx.findRecordById('users', targetId);
      if (target.getString('empresa') !== empresaId) {
        throw new ForbiddenError('Utilizador de outra empresa.');
      }
      const papelAlvo = target.getString('papel');
      if (papelCaller === 'admin' && papelAlvo !== 'editor' && papelAlvo !== 'viewer') {
        throw new ForbiddenError(
          'Só o proprietário pode repor a palavra-passe de administradores e proprietários.',
        );
      }
      senha =
        $security.randomStringWithAlphabet(5, alfabeto) +
        '-' +
        $security.randomStringWithAlphabet(5, alfabeto);
      target.setPassword(senha);
      target.refreshTokenKey(); // fecha as sessões abertas dessa conta
      target.set('senha_provisoria', true);
      tx.save(target);
    });

    e.app.logger().info('Palavra-passe provisória gerada', 'por', caller.id, 'para', targetId);
    return e.json(200, { senha: senha });
  },
  $apis.requireAuth('users'),
);

// --- Escolher a palavra-passe nova depois da provisória ---------------------
// Só serve a quem entrou com uma palavra-passe provisória. Grava a nova, tira
// a marca e fecha as sessões (a pessoa volta a entrar com a nova).
routerAdd(
  'POST',
  '/api/gc_turnkey/conta/senha',
  (e) => {
    const caller = e.auth;
    if (!caller || caller.collection().name !== 'users') {
      throw new ForbiddenError('Autenticação necessária.');
    }
    const body = e.requestInfo().body || {};
    const nova = (body.senha || '').toString();
    if (nova.length < 8) {
      throw new BadRequestError('A palavra-passe tem de ter pelo menos 8 caracteres.');
    }
    e.app.runInTransaction((tx) => {
      const u = tx.findRecordById('users', caller.id);
      if (!u.getBool('senha_provisoria')) {
        throw new BadRequestError('A tua palavra-passe não é provisória.');
      }
      if (u.validatePassword(nova)) {
        throw new BadRequestError('Escolhe uma palavra-passe diferente da provisória.');
      }
      u.setPassword(nova);
      u.refreshTokenKey();
      u.set('senha_provisoria', false);
      tx.save(u);
    });
    return e.json(200, { ok: true });
  },
  $apis.requireAuth('users'),
);

// --- Remover alguém da equipa ------------------------------------------------
// Apaga a conta (deixa de poder entrar). O que essa pessoa registou fica (o
// ponto, as férias, as faturas… guardam o nome); só desaparecem as coisas
// pessoais dela (preferências do menu e o cartão do quiosque). Não se apaga a
// própria conta nem o último proprietário; o administrador só remove Editores
// e Leitores.
routerAdd(
  'DELETE',
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
    if (targetId === caller.id) {
      throw new BadRequestError('Não podes remover a tua própria conta.');
    }

    e.app.runInTransaction((tx) => {
      const target = tx.findRecordById('users', targetId);
      if (target.getString('empresa') !== empresaId) {
        throw new ForbiddenError('Utilizador de outra empresa.');
      }
      const papelAlvo = target.getString('papel');
      if (papelCaller === 'admin' && papelAlvo !== 'editor' && papelAlvo !== 'viewer') {
        throw new ForbiddenError(
          'Só o proprietário pode remover administradores e proprietários.',
        );
      }
      if (papelAlvo === 'owner') {
        const owners = tx.findRecordsByFilter(
          'users',
          "empresa = {:e} && papel = 'owner'",
          '',
          0,
          0,
          { e: empresaId },
        );
        if (owners.length <= 1) {
          throw new BadRequestError('A empresa tem de ter pelo menos um proprietário.');
        }
      }
      tx.delete(target);
    });

    e.app.logger().info('Membro removido da equipa', 'por', caller.id, 'alvo', targetId);
    return e.json(200, { ok: true });
  },
  $apis.requireAuth('users'),
);
