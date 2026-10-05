/// <reference path="../pb_data/types.d.ts" />

// Integrações externas por empresa (tokens cifrados — ver segredos.js).
//
//   GET    /api/gc_turnkey/integracoes/{servico}   -> { configurada, sufixo, atualizadoEm }
//   PUT    /api/gc_turnkey/integracoes/{servico}   { valor }   (owner/admin)
//   DELETE /api/gc_turnkey/integracoes/{servico}               (owner/admin)
//
// O valor guardado nunca volta a sair do servidor. Serviços aceites: vendus, telegram (token do bot dos avisos).
//
// NOTA: cada handler é autocontido (os handlers correm isolados).

routerAdd(
  'GET',
  '/api/gc_turnkey/integracoes/{servico}',
  (e) => {
    const auth = e.auth;
    if (!auth || auth.collection().name !== 'users' || !auth.getString('empresa')) {
      throw new ForbiddenError('Autenticação necessária.');
    }
    if (auth.getString('papel') === 'viewer') throw new ForbiddenError('Sem permissão.');
    const servico = e.request.pathValue('servico');
    if (!['vendus', 'telegram'].includes(servico)) throw new NotFoundError('Serviço desconhecido.');
    const seg = require(`${__hooks}/segredos.js`);
    return e.json(200, seg.estado(e.app, auth.getString('empresa'), servico));
  },
  $apis.requireAuth('users'),
);

routerAdd(
  'PUT',
  '/api/gc_turnkey/integracoes/{servico}',
  (e) => {
    const auth = e.auth;
    if (!auth || auth.collection().name !== 'users' || !auth.getString('empresa')) {
      throw new ForbiddenError('Autenticação necessária.');
    }
    const papel = auth.getString('papel');
    if (papel !== 'owner' && papel !== 'admin') {
      throw new ForbiddenError('Precisas de ser administrador da empresa.');
    }
    const servico = e.request.pathValue('servico');
    if (!['vendus', 'telegram'].includes(servico)) throw new NotFoundError('Serviço desconhecido.');
    const valor = ((e.requestInfo().body || {}).valor || '').toString().trim();
    if (valor.length < 8 || valor.length > 300 || /\s/.test(valor)) {
      throw new BadRequestError('Token inválido (8 a 300 caracteres, sem espaços).');
    }
    const seg = require(`${__hooks}/segredos.js`);
    if (!seg.cifraDisponivel()) {
      throw new ApiError(
        503,
        'O servidor ainda não tem a chave de cifra (GC_TURNKEY_ENC_KEY no .env, 32 caracteres). ' +
          'No servidor Linux corre "bash gc_turnkey.sh instalar" (gera-a) e reinicia; no PC de desenvolvimento, pb\\gerar-chave-cifra.ps1 -Gravar.',
        null,
      );
    }
    try {
      seg.guardar(e.app, auth.getString('empresa'), servico, valor, auth.id);
    } catch (err) {
      console.log('[integracoes] erro ao guardar segredo: ' + String(err && err.message ? err.message : 'desconhecido'));
      throw new ApiError(503, 'Não foi possível guardar o token neste servidor (ver os registos do servidor).', null);
    }
    return e.json(200, seg.estado(e.app, auth.getString('empresa'), servico));
  },
  $apis.requireAuth('users'),
);

routerAdd(
  'DELETE',
  '/api/gc_turnkey/integracoes/{servico}',
  (e) => {
    const auth = e.auth;
    if (!auth || auth.collection().name !== 'users' || !auth.getString('empresa')) {
      throw new ForbiddenError('Autenticação necessária.');
    }
    const papel = auth.getString('papel');
    if (papel !== 'owner' && papel !== 'admin') {
      throw new ForbiddenError('Precisas de ser administrador da empresa.');
    }
    const servico = e.request.pathValue('servico');
    if (!['vendus', 'telegram'].includes(servico)) throw new NotFoundError('Serviço desconhecido.');
    const seg = require(`${__hooks}/segredos.js`);
    seg.apagar(e.app, auth.getString('empresa'), servico);
    return e.json(200, seg.estado(e.app, auth.getString('empresa'), servico));
  },
  $apis.requireAuth('users'),
);
