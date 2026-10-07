/// <reference path="../pb_data/types.d.ts" />

// Vigia de segurança do servidor (ver deploy/seguranca/vigia.py): o script
// corre no servidor Linux (como root, de 10 em 10 minutos) e escreve
// pb_data/seguranca_vigia.json. Aqui a app só LÊ esse ficheiro e mostra-o ao
// "operador da plataforma" (o dono; ver operador.js).
//
//   GET  /api/gc_turnkey/seguranca/vigia          -> { operador, instalado, estado, achados, ... }
//   POST /api/gc_turnkey/seguranca/vigia/aceitar  { id }  ("já verifiquei": o vigia aprende)
//   POST /api/gc_turnkey/seguranca/vigia/explicar { id, previa?, refazer? }
//        "Explicar com IA": o SERVIDOR monta o pedido a partir do alerta, sem IPs, emails nem nomes
//        (vigia_ia.js). Com `previa` devolve só o texto que seria enviado (nada sai).
//   cron (de 5 em 5 min)                          -> avisa (Telegram/email) dos alertas novos
//
// O "já verifiquei" escreve pb_data/seguranca_acks.json, que o vigia lê.
// NOTA: cada handler corre isolado — usa require() para o resto.

routerAdd('GET', '/api/gc_turnkey/seguranca/vigia', (e) => {
  const auth = e.auth;
  if (!auth) throw new UnauthorizedError('Autenticação necessária.');
  const { ehOperador } = require(`${__hooks}/operador.js`);
  if (!ehOperador(e.app, auth)) return e.json(200, { operador: false });
  return e.json(200, require(`${__hooks}/vigia_core.js`).estado(e.app));
});

routerAdd('POST', '/api/gc_turnkey/seguranca/vigia/aceitar', (e) => {
  const auth = e.auth;
  if (!auth) throw new UnauthorizedError('Autenticação necessária.');
  const { ehOperador } = require(`${__hooks}/operador.js`);
  if (!ehOperador(e.app, auth)) throw new ForbiddenError('Só o dono do servidor aceita alertas de segurança.');
  const body = e.requestInfo().body || {};
  const id = String(body.id || '').substring(0, 300);
  if (!id) throw new BadRequestError('Falta o alerta.');
  const r = require(`${__hooks}/vigia_core.js`).aceitar(e.app, id, auth.getString('email'));
  if (!r.ok) throw new BadRequestError(r.mensagem);
  return e.json(200, { ok: true });
});

routerAdd('POST', '/api/gc_turnkey/seguranca/vigia/explicar', (e) => {
  const auth = e.auth;
  if (!auth) throw new UnauthorizedError('Autenticação necessária.');
  const { ehOperador } = require(`${__hooks}/operador.js`);
  if (!ehOperador(e.app, auth)) throw new ForbiddenError('Só o dono do servidor pede explicações de segurança.');
  const body = e.requestInfo().body || {};
  const id = String(body.id || '').substring(0, 300);
  if (!id) throw new BadRequestError('Falta o alerta.');
  const r = require(`${__hooks}/vigia_core.js`).explicar(e.app, id, {
    previa: body.previa === true,
    refazer: body.refazer === true,
  });
  if (r.erro) throw new ApiError(r.erro.code, r.erro.message, null);
  return e.json(200, r.ok);
});

// Avisa dos alertas novos (críticos e de atenção) pelos canais do dono.
cronAdd('vigia_aviso', '*/5 * * * *', () => {
  try {
    require(`${__hooks}/vigia_core.js`).avisarNovos($app);
  } catch (err) {
    console.log('[vigia] erro ao avisar: ' + String(err && err.message ? err.message : 'desconhecido'));
  }
});
