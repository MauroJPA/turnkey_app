// Telegram de cada pessoa (módulo partilhado via require()).
//
// Cada pessoa liga o seu Telegram uma vez: a app pede um código e abre o bot
// da empresa com `t.me/<bot>?start=<código>`; ao carregar em "Iniciar", o
// Telegram manda "/start <código>" e a sondagem de minuto a minuto
// (telegram_botoes.js → sondar) entrega-o aqui. A partir daí, o que é só dela
// (as menções nas Tarefas) vai para essa conversa.
//
// Segurança: só conversas privadas; o código é de uso único, ao acaso, vale
// 30 minutos e está escondido da API; o token do bot nunca sai daqui.

const URL_BASE = () => $os.getenv('GC_TURNKEY_TELEGRAM_URL') || 'https://api.telegram.org';
const VALIDADE_MIN = 30;

function api(token, metodo, corpo) {
  try {
    const r = $http.send({
      url: URL_BASE() + '/bot' + token + '/' + metodo,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(corpo || {}),
      timeout: 15,
    });
    return r.statusCode === 200 ? r.json : null;
  } catch (_) {
    return null;
  }
}

function lerJson(app, nome, vazio) {
  try {
    return JSON.parse(toString($os.readFile(String(app.dataDir()) + '/' + nome)));
  } catch (_) {
    return vazio;
  }
}

function gravarJson(app, nome, obj) {
  try {
    $os.writeFile(String(app.dataDir()) + '/' + nome, JSON.stringify(obj), 0o644);
  } catch (_) {}
}

// O Telegram da empresa está ligado? Devolve o token ou ''.
function tokenAtivo(app, empresaId) {
  try {
    const cfg = app.findFirstRecordByFilter('avisos_config', 'empresa = {:e}', { e: empresaId });
    if (!cfg.getBool('telegram_ativo')) return '';
  } catch (_) {
    return '';
  }
  return require(__hooks + '/segredos.js').ler(app, empresaId, 'telegram') || '';
}

// O nome do bot (para o link t.me), guardado por um dia.
function nomeDoBot(app, empresaId, token) {
  const ficheiro = 'telegram_bot_' + empresaId + '.json';
  const guardado = lerJson(app, ficheiro, {});
  if (guardado.u && Date.now() - (guardado.em || 0) < 86400000) return guardado.u;
  const r = api(token, 'getMe', {});
  const u = r && r.result && r.result.username ? String(r.result.username) : '';
  if (u) gravarJson(app, ficheiro, { u: u, em: Date.now() });
  return u;
}

function codigoNovo() {
  return 'L' + $security.randomStringWithAlphabet(23, 'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789');
}

// Pede uma ligação para [userId]: { ok, link, bot } ou { ok: false, erro }.
function pedirLigacao(app, empresaId, userId) {
  const token = tokenAtivo(app, empresaId);
  if (!token) return { ok: false, erro: 'A administração ainda não ligou o Telegram (Opções → Avisos).' };
  const bot = nomeDoBot(app, empresaId, token);
  if (!bot) return { ok: false, erro: 'Não consegui falar com o bot do Telegram. Tenta daqui a pouco.' };
  let rec;
  try {
    rec = app.findFirstRecordByFilter('telegram_pessoas', 'user = {:u}', { u: userId });
  } catch (_) {
    rec = new Record(app.findCollectionByNameOrId('telegram_pessoas'));
    rec.set('user', userId);
  }
  rec.set('empresa', empresaId);
  const codigo = codigoNovo();
  rec.set('codigo', codigo);
  rec.set('expira', new Date(Date.now() + VALIDADE_MIN * 60000).toISOString().replace('T', ' '));
  app.save(rec);
  return { ok: true, link: 'https://t.me/' + bot + '?start=' + codigo, bot: bot };
}

// Guarda os chats que falaram com o bot (para o "Detetar o meu chat" da
// administração, que já não os vê no Telegram depois de a sondagem os ler).
function lembrarChat(app, empresaId, chat) {
  if (!chat || chat.id === undefined) return;
  const ficheiro = 'telegram_chats_' + empresaId + '.json';
  const estado = lerJson(app, ficheiro, { chats: [] });
  const nome = String(chat.title || [chat.first_name, chat.last_name].filter(Boolean).join(' ') || chat.username || 'chat').substring(0, 60);
  const lista = [{ id: String(chat.id), nome: nome }].concat((estado.chats || []).filter((c) => c.id !== String(chat.id)));
  gravarJson(app, ficheiro, { chats: lista.slice(0, 10) });
}

function chatsLembrados(app, empresaId) {
  return (lerJson(app, 'telegram_chats_' + empresaId + '.json', { chats: [] }).chats || []).slice(0, 10);
}

// Trata uma mensagem que chegou ao bot da empresa. Devolve true se ligou alguém.
function tratarMensagem(app, empresaId, token, msg) {
  const chat = (msg && msg.chat) || {};
  lembrarChat(app, empresaId, chat);
  const m = /^\/start\s+([A-Za-z0-9]{8,40})\s*$/.exec(String(msg.text || ''));
  if (!m) return false;
  const responder = (texto) => api(token, 'sendMessage', { chat_id: chat.id, text: texto });
  if (chat.type !== 'private' || !msg.from || String(msg.from.id) !== String(chat.id)) {
    responder('Liga o teu Telegram numa conversa privada com o bot, não num grupo.');
    return false;
  }
  let rec = null;
  try {
    rec = app.findFirstRecordByFilter('telegram_pessoas', "empresa = {:e} && codigo = {:c} && codigo != ''", { e: empresaId, c: m[1] });
  } catch (_) {
    rec = null;
  }
  const expira = rec ? new Date(String(rec.getString('expira')).replace(' ', 'T')).getTime() : 0;
  if (!rec || !expira || expira < Date.now()) {
    responder('Este código já não vale. Na app, abre Tarefas → ⋮ → "Menções no Telegram" e liga outra vez.');
    return false;
  }
  rec.set('chat', String(chat.id));
  rec.set('nome', String([chat.first_name, chat.last_name].filter(Boolean).join(' ') || chat.username || '').substring(0, 80));
  rec.set('codigo', '');
  rec.set('expira', '');
  app.save(rec);
  responder('✅ Ligado! A partir de agora recebes aqui quando alguém te mencionar nas Tarefas.');
  return true;
}

function curto(s, n) {
  const t = String(s || '').replace(/\s+/g, ' ').trim();
  return t.length <= n ? t : t.substring(0, n - 1).trim() + '…';
}

// Avisa no Telegram cada pessoa em [ids] (menos o autor) de que foi mencionada
// no comentário [com]. Devolve quantas mensagens enviou.
function avisarMencoes(app, com, ids) {
  const empresaId = com.getString('empresa');
  const autor = com.getString('autor');
  const alvos = (ids || []).filter((id, i, l) => id && id !== autor && l.indexOf(id) === i);
  if (!alvos.length) return 0;
  const token = tokenAtivo(app, empresaId);
  if (!token) return 0;
  let tarefa;
  try {
    tarefa = app.findRecordById('tarefas', com.getString('tarefa'));
  } catch (_) {
    return 0;
  }
  if (tarefa.getString('empresa') !== empresaId || tarefa.getBool('arquivada')) return 0;
  let quadro = '';
  try {
    quadro = app.findRecordById('quadros', tarefa.getString('quadro')).getString('nome');
  } catch (_) {}
  const quem = com.getString('autor_nome') || 'Alguém';
  const base = ($os.getenv('GC_TURNKEY_APP_URL') || '').replace(/\/+$/, '');
  const texto =
    '💬 ' + quem + ' mencionou-te em «' + curto(tarefa.getString('titulo'), 80) + '»' + (quadro ? ' (' + curto(quadro, 40) + ')' : '') + ':\n' +
    curto(com.getString('texto'), 600) +
    (base ? '\n\nAbrir: ' + base + '/#/tarefas?t=' + tarefa.id : '');
  const avisos = require(__hooks + '/avisos.js');
  let n = 0;
  for (const id of alvos) {
    let p;
    try {
      p = app.findFirstRecordByFilter('telegram_pessoas', "user = {:u} && empresa = {:e} && chat != ''", { u: id, e: empresaId });
    } catch (_) {
      continue;
    }
    // quem saiu da empresa já não recebe
    try {
      if (app.findRecordById('users', id).getString('empresa') !== empresaId) continue;
    } catch (_) {
      continue;
    }
    if (avisos.enviarTelegram(token, p.getString('chat'), texto, null) === '') n++;
  }
  return n;
}

module.exports = { pedirLigacao, tratarMensagem, avisarMencoes, chatsLembrados, tokenAtivo };
