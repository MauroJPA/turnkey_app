/// <reference path="../pb_data/types.d.ts" />

// Telegram de cada pessoa (ver telegram_pessoas.js):
//   POST /api/gc_turnkey/telegram/pessoal/ligar     -> { link, bot }  (abre o bot com o código)
//   POST /api/gc_turnkey/telegram/pessoal/verificar -> { ligado, nome } (vê já se a pessoa carregou em "Iniciar")
//   POST /api/gc_turnkey/telegram/pessoal/testar    -> { enviado }    (mensagem de teste para a própria pessoa)
// Qualquer pessoa da empresa (também a Leitura): é só sobre o seu próprio Telegram.
// NOTA: cada handler corre isolado — usa require() para o resto.

routerAdd(
  'POST',
  '/api/gc_turnkey/telegram/pessoal/ligar',
  (e) => {
    const auth = e.auth;
    if (!auth || auth.collection().name !== 'users' || !auth.getString('empresa')) {
      throw new ForbiddenError('Autenticação necessária.');
    }
    let r;
    try {
      r = require(`${__hooks}/telegram_pessoas.js`).pedirLigacao(e.app, auth.getString('empresa'), auth.id);
    } catch (err) {
      console.log('[telegram] ligar: ' + String(err && err.message ? err.message : 'desconhecido').replace(/bot[0-9]+:[A-Za-z0-9_-]+/g, 'bot***'));
      throw new ApiError(500, 'Não foi possível preparar a ligação ao Telegram.', null);
    }
    if (!r.ok) throw new BadRequestError(r.erro);
    return e.json(200, { link: r.link, bot: r.bot });
  },
  $apis.requireAuth('users'),
);

routerAdd(
  'POST',
  '/api/gc_turnkey/telegram/pessoal/verificar',
  (e) => {
    const auth = e.auth;
    if (!auth || auth.collection().name !== 'users' || !auth.getString('empresa')) {
      throw new ForbiddenError('Autenticação necessária.');
    }
    const empresaId = auth.getString('empresa');
    try {
      require(`${__hooks}/telegram_botoes.js`).sondar(e.app, empresaId);
    } catch (err) {
      console.log('[telegram] verificar: ' + String(err && err.message ? err.message : 'desconhecido').replace(/bot[0-9]+:[A-Za-z0-9_-]+/g, 'bot***'));
    }
    let rec = null;
    try {
      rec = e.app.findFirstRecordByFilter('telegram_pessoas', 'user = {:u} && empresa = {:e}', { u: auth.id, e: empresaId });
    } catch (_) {
      rec = null;
    }
    const ligado = !!(rec && rec.getString('chat'));
    return e.json(200, { ligado: ligado, nome: ligado ? rec.getString('nome') : '' });
  },
  $apis.requireAuth('users'),
);

routerAdd(
  'POST',
  '/api/gc_turnkey/telegram/pessoal/testar',
  (e) => {
    const auth = e.auth;
    if (!auth || auth.collection().name !== 'users' || !auth.getString('empresa')) {
      throw new ForbiddenError('Autenticação necessária.');
    }
    const empresaId = auth.getString('empresa');
    const tp = require(`${__hooks}/telegram_pessoas.js`);
    const token = tp.tokenAtivo(e.app, empresaId);
    if (!token) throw new BadRequestError('A administração ainda não ligou o Telegram (Opções → Avisos).');
    let rec;
    try {
      rec = e.app.findFirstRecordByFilter('telegram_pessoas', "user = {:u} && empresa = {:e} && chat != ''", { u: auth.id, e: empresaId });
    } catch (_) {
      throw new BadRequestError('O teu Telegram ainda não está ligado.');
    }
    const erro = require(`${__hooks}/avisos.js`).enviarTelegram(token, rec.getString('chat'), '👋 Teste: é aqui que recebes as tuas menções nas Tarefas.', null);
    if (erro) throw new BadRequestError(erro);
    return e.json(200, { enviado: true });
  },
  $apis.requireAuth('users'),
);
