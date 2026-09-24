/// <reference path="../pb_data/types.d.ts" />

// Integrações externas por empresa (tokens cifrados — ver segredos.js).
//
//   GET    /api/turnkey/integracoes/{servico}   -> { configurada, sufixo, atualizadoEm }
//   PUT    /api/turnkey/integracoes/{servico}   { valor }   (owner/admin)
//   DELETE /api/turnkey/integracoes/{servico}               (owner/admin)
//
// O valor guardado nunca volta a sair do servidor. Serviços aceites: vendus.
//
// NOTA: cada handler é autocontido (os handlers correm isolados).

routerAdd(
  'GET',
  '/api/turnkey/integracoes/{servico}',
  (e) => {
    const auth = e.auth;
    if (!auth || auth.collection().name !== 'users' || !auth.getString('empresa')) {
      throw new ForbiddenError('Autenticação necessária.');
    }
    if (auth.getString('papel') === 'viewer') throw new ForbiddenError('Sem permissão.');
    const servico = e.request.pathValue('servico');
    if (!['vendus'].includes(servico)) throw new NotFoundError('Serviço desconhecido.');
    const seg = require(`${__hooks}/segredos.js`);
    return e.json(200, seg.estado(e.app, auth.getString('empresa'), servico));
  },
  $apis.requireAuth('users'),
);

routerAdd(
  'PUT',
  '/api/turnkey/integracoes/{servico}',
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
    if (!['vendus'].includes(servico)) throw new NotFoundError('Serviço desconhecido.');
    const valor = ((e.requestInfo().body || {}).valor || '').toString().trim();
    if (valor.length < 8 || valor.length > 300 || /\s/.test(valor)) {
      throw new BadRequestError('Token inválido (8 a 300 caracteres, sem espaços).');
    }
    const seg = require(`${__hooks}/segredos.js`);
    try {
      seg.guardar(e.app, auth.getString('empresa'), servico, valor, auth.id);
    } catch (err) {
      throw new ApiError(503, 'Não foi possível guardar o token de forma segura neste servidor.', null);
    }
    return e.json(200, seg.estado(e.app, auth.getString('empresa'), servico));
  },
  $apis.requireAuth('users'),
);

routerAdd(
  'DELETE',
  '/api/turnkey/integracoes/{servico}',
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
    if (!['vendus'].includes(servico)) throw new NotFoundError('Serviço desconhecido.');
    const seg = require(`${__hooks}/segredos.js`);
    seg.apagar(e.app, auth.getString('empresa'), servico);
    return e.json(200, { configurada: false, sufixo: '', atualizadoEm: '' });
  },
  $apis.requireAuth('users'),
);
