/// <reference path="../pb_data/types.d.ts" />

// Avisos e resumo diário por email e Telegram (ver avisos.js).
//
//   cron (todos os minutos)                      -> envia o resumo à hora de cada empresa
//   cron (todos os minutos)                      -> envia o resumo semanal no dia escolhido
//   POST /api/gc_turnkey/avisos/testar           { enviar: bool, semanal?: bool } -> { texto, resultados }
//   POST /api/gc_turnkey/avisos/telegram/detetar -> { chats: [{ id, nome }] }
//
// Só owner/admin. NOTA: cada handler corre isolado — usa require() para o resto.

cronAdd('avisos_diarios', '* * * * *', () => {
  const avisos = require(`${__hooks}/avisos.js`);
  const seg = require(`${__hooks}/segredos.js`);
  let cfgs = [];
  try {
    cfgs = $app.findRecordsByFilter('avisos_config', 'ativo = true', '', 0, 0);
  } catch (_) {
    return;
  }
  const agora = new Date();
  const hoje = avisos.hojeISO(agora);
  const minAgora = agora.getHours() * 60 + agora.getMinutes();
  for (const cfg of cfgs) {
    try {
      if (cfg.getString('ultimo_envio') === hoje) continue;
      const m = /^(\d{1,2}):(\d{2})$/.exec(cfg.getString('hora') || '08:00');
      const alvo = m ? parseInt(m[1], 10) * 60 + parseInt(m[2], 10) : 8 * 60;
      // à hora marcada ou, se o servidor esteve parado, até 3 h depois
      if (minAgora < alvo || minAgora > alvo + 180) continue;
      const empresaId = cfg.getString('empresa');
      const resumo = avisos.montar($app, empresaId, cfg);
      cfg.set('ultimo_envio', hoje);
      if (resumo.fechado) {
        // dia de folga: não incomoda ninguém
        cfg.set('ultimo_resultado', 'Dia de folga: não enviado.');
        $app.save(cfg);
        continue;
      }
      const res = avisos.enviar($app, empresaId, cfg, resumo, seg.ler);
      cfg.set('ultimo_resultado', avisos.descrever(res).substring(0, 390));
      $app.save(cfg);
    } catch (err) {
      console.log('[avisos] erro no envio diário: ' + String(err && err.message ? err.message : 'desconhecido'));
    }
  }
});

// Resumo semanal: no dia da semana escolhido (1 = segunda ... 7 = domingo), à
// mesma hora do diário. Envia mesmo que seja dia de folga (foi o dono que
// escolheu o dia).
cronAdd('avisos_semanais', '* * * * *', () => {
  const avisos = require(`${__hooks}/avisos.js`);
  const semanal = require(`${__hooks}/resumo_semanal.js`);
  const seg = require(`${__hooks}/segredos.js`);
  let cfgs = [];
  try {
    cfgs = $app.findRecordsByFilter('avisos_config', 'ativo = true && semanal_ativo = true', '', 0, 0);
  } catch (_) {
    return;
  }
  const agora = new Date();
  const hoje = avisos.hojeISO(agora);
  const dow = agora.getDay() === 0 ? 7 : agora.getDay();
  const minAgora = agora.getHours() * 60 + agora.getMinutes();
  for (const cfg of cfgs) {
    try {
      if (cfg.getString('ultimo_semanal') === hoje) continue;
      if ((cfg.getInt('semanal_dia') || 1) !== dow) continue;
      const m = /^(\d{1,2}):(\d{2})$/.exec(cfg.getString('hora') || '08:00');
      const alvo = m ? parseInt(m[1], 10) * 60 + parseInt(m[2], 10) : 8 * 60;
      if (minAgora < alvo || minAgora > alvo + 180) continue;
      const empresaId = cfg.getString('empresa');
      const resumo = semanal.montar($app, empresaId, agora);
      cfg.set('ultimo_semanal', hoje);
      const res = avisos.enviar($app, empresaId, cfg, resumo, seg.ler);
      cfg.set('ultimo_resultado', ('Semanal: ' + avisos.descrever(res)).substring(0, 390));
      $app.save(cfg);
    } catch (err) {
      console.log('[avisos] erro no envio semanal: ' + String(err && err.message ? err.message : 'desconhecido'));
    }
  }
});

routerAdd(
  'POST',
  '/api/gc_turnkey/avisos/testar',
  (e) => {
    const auth = e.auth;
    if (!auth || auth.collection().name !== 'users' || !auth.getString('empresa')) {
      throw new ForbiddenError('Autenticação necessária.');
    }
    const papel = auth.getString('papel');
    if (papel !== 'owner' && papel !== 'admin') throw new ForbiddenError('Precisas de ser administrador.');
    const empresaId = auth.getString('empresa');
    const avisos = require(`${__hooks}/avisos.js`);
    const seg = require(`${__hooks}/segredos.js`);
    try {
      const cfg = avisos.configDaEmpresa(e.app, empresaId);
      const semanal = ((e.requestInfo().body || {}).semanal) === true;
      const resumo = semanal
        ? require(`${__hooks}/resumo_semanal.js`).montar(e.app, empresaId)
        : avisos.montar(e.app, empresaId, cfg);
      const enviar = ((e.requestInfo().body || {}).enviar) === true;
      const resultados = enviar ? avisos.enviar(e.app, empresaId, cfg, resumo, seg.ler) : {};
      return e.json(200, { texto: resumo.texto, resultados: resultados, descricao: enviar ? avisos.descrever(resultados) : '' });
    } catch (err) {
      const msg = String(err && err.message ? err.message : err).substring(0, 200);
      console.log('[avisos] testar: ' + msg);
      throw new ApiError(500, 'Não consegui montar o resumo (' + msg.replace(/bot[0-9]+:[A-Za-z0-9_-]+/g, 'bot***') + ').', null);
    }
  },
  $apis.requireAuth('users'),
);

routerAdd(
  'POST',
  '/api/gc_turnkey/avisos/telegram/detetar',
  (e) => {
    const auth = e.auth;
    if (!auth || auth.collection().name !== 'users' || !auth.getString('empresa')) {
      throw new ForbiddenError('Autenticação necessária.');
    }
    const papel = auth.getString('papel');
    if (papel !== 'owner' && papel !== 'admin') throw new ForbiddenError('Precisas de ser administrador.');
    const seg = require(`${__hooks}/segredos.js`);
    const token = seg.ler(e.app, auth.getString('empresa'), 'telegram');
    if (!token) throw new BadRequestError('Guarda primeiro o token do bot do Telegram.');
    let r;
    try {
      r = $http.send({
        url: ($os.getenv('GC_TURNKEY_TELEGRAM_URL') || 'https://api.telegram.org') + '/bot' + token + '/getUpdates',
        method: 'GET',
        timeout: 20,
      });
    } catch (_) {
      throw new ApiError(502, 'Não consegui contactar o Telegram.', null);
    }
    if (r.statusCode === 401) throw new BadRequestError('O token do bot é inválido.');
    if (r.statusCode !== 200) throw new ApiError(502, 'O Telegram devolveu um erro (' + r.statusCode + ').', null);
    const vistos = {};
    const chats = [];
    // a sondagem de minuto a minuto já pode ter lido as mensagens: começa pelas
    // que ela guardou (mais recentes primeiro)
    try {
      for (const c of require(`${__hooks}/telegram_pessoas.js`).chatsLembrados(e.app, auth.getString('empresa'))) {
        if (vistos[c.id]) continue;
        vistos[c.id] = true;
        chats.push({ id: String(c.id), nome: String(c.nome || 'chat').substring(0, 60) });
      }
    } catch (_) {}
    const lista = (r.json && r.json.result) || [];
    for (let i = lista.length - 1; i >= 0; i--) {
      const m = lista[i].message || lista[i].channel_post || lista[i].my_chat_member || null;
      const chat = m && m.chat;
      if (!chat || vistos[chat.id]) continue;
      vistos[chat.id] = true;
      chats.push({ id: String(chat.id), nome: String(chat.title || [chat.first_name, chat.last_name].filter(Boolean).join(' ') || chat.username || 'chat').substring(0, 60) });
    }
    return e.json(200, { chats: chats.slice(0, 5) });
  },
  $apis.requireAuth('users'),
);
