/// <reference path="../pb_data/types.d.ts" />

// Verificação em 2 passos (palavra-passe + código enviado por email) para os
// administradores (owner e admin) da app.
//
//   GET  /api/gc_turnkey/seguranca/2fa            -> { ativo, smtp, podeAlterar }
//   POST /api/gc_turnkey/seguranca/2fa { ativo }  -> o mesmo (só o proprietário)
//
// Usa o MFA do PocketBase: com a regra abaixo, quem for owner/admin tem de passar
// por DOIS métodos (palavra-passe + código OTP por email). Os restantes papéis
// (equipa, quiosque) entram como antes: o tablet do quiosque não pede código.
//
// Só liga se o servidor conseguir enviar emails (SMTP ativo); sem isso ficava
// toda a gente de fora. Se alguém ficar trancado: entrar em /_/ como
// superutilizador e desligar "Multi-factor authentication" na coleção users
// (docs/SEGURANCA.md).
//
// NOTA: cada handler é autocontido (os handlers correm isolados).

routerAdd(
  'GET',
  '/api/gc_turnkey/seguranca/2fa',
  (e) => {
    const auth = e.auth;
    if (!auth || auth.collection().name !== 'users') throw new ForbiddenError('Autenticação necessária.');
    const papel = auth.getString('papel');
    if (papel !== 'owner' && papel !== 'admin') throw new ForbiddenError('Só administradores.');
    const col = e.app.findCollectionByNameOrId('users');
    return e.json(200, {
      ativo: !!col.mfa.enabled && !!col.otp.enabled,
      smtp: !!e.app.settings().smtp.enabled,
      podeAlterar: papel === 'owner',
    });
  },
  $apis.requireAuth('users'),
);

routerAdd(
  'POST',
  '/api/gc_turnkey/seguranca/2fa',
  (e) => {
    const auth = e.auth;
    if (!auth || auth.collection().name !== 'users') throw new ForbiddenError('Autenticação necessária.');
    if (auth.getString('papel') !== 'owner') {
      throw new ForbiddenError('Só o proprietário liga ou desliga a verificação em 2 passos.');
    }
    const ativo = (e.requestInfo().body || {}).ativo;
    if (typeof ativo !== 'boolean') throw new BadRequestError('Indica "ativo": true ou false.');
    const smtp = !!e.app.settings().smtp.enabled;
    if (ativo && !smtp) {
      throw new BadRequestError(
        'O servidor ainda não consegue enviar emails (SMTP), por isso os códigos não chegariam. ' +
          'Configura o SMTP primeiro (docs/SEGURANCA.md).',
      );
    }
    if (ativo && !auth.getString('email')) {
      throw new BadRequestError('A tua conta não tem email para receber os códigos.');
    }
    const col = e.app.findCollectionByNameOrId('users');
    if (ativo) {
      col.mfa.enabled = true;
      col.mfa.duration = 1800;
      col.mfa.rule = "papel = 'owner' || papel = 'admin'";
      col.otp.enabled = true;
      col.otp.duration = 300;
      col.otp.length = 6;
    } else {
      col.mfa.enabled = false;
      col.mfa.rule = '';
      col.otp.enabled = false;
    }
    e.app.save(col);
    return e.json(200, {
      ativo: !!col.mfa.enabled && !!col.otp.enabled,
      smtp: smtp,
      podeAlterar: true,
    });
  },
  $apis.requireAuth('users'),
);
