// Telegram com botões (módulo partilhado via require()).
//
// Algumas mensagens do bot trazem botões ("Aprovar", "Saída às 16:30", "Já
// verifiquei"). Como o servidor não tem endereço público, não há webhook: de
// minuto a minuto (cron) vai-se perguntar ao Telegram o que foi carregado
// (`getUpdates`) e trata-se.
//
// Segurança:
//  - os botões só vão em CONVERSA PRIVADA (um grupo deixava qualquer membro
//    carregar) e só se tratam carregamentos vindos desse mesmo chat;
//  - cada botão leva uma assinatura (HMAC com o token do bot) que liga a ação,
//    o alvo e a empresa — um pedido inventado ou de outra empresa é recusado;
//  - cada ação confere o estado atual (só se aprova o que ainda está "por
//    aprovar", só se marca a saída de quem ainda está dentro…): carregar duas
//    vezes não faz nada de novo;
//  - o token nunca vai para mensagens nem para o registo.
//
// callback_data: "p|<tipo>|<alvo>|<assinatura>" (máx. 64 bytes).
//   fa/fr = aprovar/recusar ausência (alvo = id)
//   sx    = marcar saída (alvo = pessoa~epoch-segundos)
//   va    = "já verifiquei" no vigia (alvo = 10 primeiros do sha256 do id)

const URL_BASE = () => $os.getenv('GC_TURNKEY_TELEGRAM_URL') || 'https://api.telegram.org';

function assinar(token, empresaId, tipo, alvo) {
  return String($security.hs256(tipo + '|' + alvo + '|' + empresaId, token)).substring(0, 10);
}

// acoes: [{ texto, tipo, id }] -> teclado (uma linha por 2 botões)
function teclado(token, empresaId, acoes) {
  const botoes = acoes.map((a) => ({
    text: String(a.texto).substring(0, 40),
    callback_data: 'p|' + a.tipo + '|' + a.id + '|' + assinar(token, empresaId, a.tipo, a.id),
  }));
  const linhas = [];
  for (let i = 0; i < botoes.length; i += 2) linhas.push(botoes.slice(i, i + 2));
  return linhas;
}

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

// ---- pequenos ficheiros de estado em pb_data (offset do Telegram, avisos feitos)
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

function dono(app, empresaId) {
  try {
    const l = app.findRecordsByFilter('users', "empresa = {:e} && papel = 'owner'", 'created', 1, 0, { e: empresaId });
    return l.length ? l[0] : null;
  } catch (_) {
    return null;
  }
}

function dmy(txt) {
  const p = String(txt).substring(0, 10).split('-');
  return p.length === 3 ? parseInt(p[2], 10) + '/' + parseInt(p[1], 10) : String(txt);
}

// ---- o que cada botão faz. Devolve a frase que fica na mensagem.
function acaoFerias(app, empresaId, aprovar, id) {
  let rec;
  try {
    rec = app.findRecordById('ferias', id);
  } catch (_) {
    return { ok: false, texto: 'Esse pedido já não existe.' };
  }
  if (rec.getString('empresa') !== empresaId) return { ok: false, texto: 'Pedido inválido.' };
  const nome = rec.getString('nome') || 'A pessoa';
  const estado = rec.getString('estado');
  if (estado !== 'pedido') {
    return { ok: false, texto: 'Já estava ' + (estado === 'aprovado' ? 'aprovado' : 'recusado') + '.' };
  }
  const d = dono(app, empresaId);
  rec.set('estado', aprovar ? 'aprovado' : 'recusado');
  if (d) rec.set('decidido_por', d.id);
  rec.set('decidido_em', new Date().toISOString().substring(0, 10) + ' 00:00:00.000Z');
  app.save(rec);
  const periodo = dmy(rec.getString('data_inicio')) + ' a ' + dmy(rec.getString('data_fim'));
  return { ok: true, texto: (aprovar ? 'Aprovado' : 'Recusado') + ': ' + nome + ', ' + periodo + '.' };
}

function acaoSaida(app, empresaId, alvo) {
  const i = alvo.lastIndexOf('~');
  const pessoa = i > 0 ? alvo.substring(0, i) : '';
  const epoch = i > 0 ? parseInt(alvo.substring(i + 1), 10) : 0;
  if (!pessoa || !epoch) return { ok: false, texto: 'Pedido inválido.' };
  const quando = new Date(epoch * 1000);
  if (quando.getTime() > Date.now() + 60000) return { ok: false, texto: 'Essa hora ainda não chegou.' };
  const desde = new Date(Date.now() - 72 * 3600 * 1000).toISOString().replace('T', ' ');
  let ultimo = null;
  try {
    const l = app.findRecordsByFilter('ponto_registos', 'empresa = {:e} && pessoa = {:p} && data_hora >= {:d}', '-data_hora', 1, 0, { e: empresaId, p: pessoa, d: desde });
    ultimo = l.length ? l[0] : null;
  } catch (_) {
    ultimo = null;
  }
  if (!ultimo) return { ok: false, texto: 'Não encontrei a entrada.' };
  const nome = ultimo.getString('nome') || 'A pessoa';
  if (ultimo.getString('tipo') === 'saida') return { ok: false, texto: nome + ' já tinha a saída marcada.' };
  const entrada = new Date(String(ultimo.getString('data_hora')).replace(' ', 'T'));
  if (quando.getTime() <= entrada.getTime()) return { ok: false, texto: 'A saída seria antes da última marcação.' };
  const rec = new Record(app.findCollectionByNameOrId('ponto_registos'));
  rec.set('empresa', empresaId);
  rec.set('pessoa', pessoa);
  rec.set('nome', nome);
  const u = ultimo.getString('user');
  if (u) rec.set('user', u);
  rec.set('tipo', 'saida');
  rec.set('data_hora', quando.toISOString().replace('T', ' '));
  rec.set('origem', 'manual');
  rec.set('notas', 'Saída marcada pelo Telegram');
  const d = dono(app, empresaId);
  if (d) rec.set('autor', d.id);
  app.save(rec);
  const hm = (n) => (n < 10 ? '0' + n : '' + n);
  return { ok: true, texto: 'Saída de ' + nome + ' marcada às ' + hm(quando.getHours()) + ':' + hm(quando.getMinutes()) + '.' };
}

function acaoVigia(app, alvo) {
  const core = require(__hooks + '/vigia_core.js');
  const e = core.estado(app);
  const achado = (e.achados || []).find((a) => $security.sha256(a.id).substring(0, 10) === alvo);
  if (!achado) return { ok: false, texto: 'Esse alerta já não está ativo.' };
  if (achado.gravidade === 'critico') return { ok: false, texto: 'Alertas críticos só se aceitam na app.' };
  if (achado.aceite) return { ok: false, texto: 'Já estava aceite.' };
  const r = core.aceitar(app, achado.id, 'telegram');
  return r.ok ? { ok: true, texto: 'O vigia aprende isto na próxima ronda: ' + achado.titulo } : { ok: false, texto: 'Não foi possível aceitar.' };
}

// ---- trata um carregamento (callback_query) de um chat da empresa
function tratar(app, empresaId, token, chatConfigurado, cb) {
  const responder = (texto) => api(token, 'answerCallbackQuery', { callback_query_id: cb.id, text: String(texto).substring(0, 180) });
  const msg = cb.message || {};
  const chat = msg.chat || {};
  const de = cb.from || {};
  if (String(chat.id) !== String(chatConfigurado) || chat.type !== 'private' || String(de.id) !== String(chat.id)) {
    responder('Este botão só funciona na conversa privada do administrador.');
    return { tratado: false };
  }
  const p = String(cb.data || '').split('|');
  if (p.length !== 4 || p[0] !== 'p') {
    responder('Pedido inválido.');
    return { tratado: false };
  }
  const tipo = p[1];
  const alvo = p[2];
  if (assinar(token, empresaId, tipo, alvo) !== p[3]) {
    responder('Pedido inválido.');
    return { tratado: false };
  }
  let r;
  try {
    if (tipo === 'fa' || tipo === 'fr') r = acaoFerias(app, empresaId, tipo === 'fa', alvo);
    else if (tipo === 'sx') r = acaoSaida(app, empresaId, alvo);
    else if (tipo === 'va') r = acaoVigia(app, alvo);
    else r = { ok: false, texto: 'Pedido inválido.' };
  } catch (_) {
    r = { ok: false, texto: 'Não foi possível fazer isso agora. Tenta na app.' };
  }
  responder(r.texto);
  // tira os botões e deixa o resultado na mensagem
  api(token, 'editMessageText', {
    chat_id: chat.id,
    message_id: msg.message_id,
    text: String(msg.text || '').substring(0, 3500) + '\n\n' + (r.ok ? '✅ ' : 'ℹ️ ') + r.texto,
  });
  return { tratado: true, ok: r.ok };
}

// Uma passagem: pergunta ao Telegram o que foi carregado em cada empresa com o
// Telegram ligado (e conversa configurada). Devolve quantos botões tratou.
function sondar(app, soEmpresa) {
  const seg = require(__hooks + '/segredos.js');
  let cfgs = [];
  try {
    cfgs = app.findRecordsByFilter('avisos_config', "telegram_ativo = true && telegram_chat != ''", '', 100, 0);
  } catch (_) {
    return { tratados: 0 };
  }
  let tratados = 0;
  for (const cfg of cfgs) {
    const empresaId = cfg.getString('empresa');
    if (soEmpresa && empresaId !== soEmpresa) continue;
    const chat = cfg.getString('telegram_chat');
    if (String(chat).charAt(0) === '-') continue; // grupos não têm botões
    const token = seg.ler(app, empresaId, 'telegram');
    if (!token) continue;
    const ficheiro = 'telegram_offset_' + empresaId + '.json';
    const estado = lerJson(app, ficheiro, { offset: 0 });
    let r = null;
    try {
      const resp = $http.send({
        url: URL_BASE() + '/bot' + token + '/getUpdates?timeout=0&allowed_updates=%5B%22callback_query%22%5D&offset=' + (Number(estado.offset) || 0),
        method: 'GET',
        timeout: 15,
      });
      r = resp.statusCode === 200 ? resp.json : null;
    } catch (_) {
      r = null;
    }
    const lista = (r && r.result) || [];
    let offset = Number(estado.offset) || 0;
    for (const u of lista) {
      if (typeof u.update_id === 'number' && u.update_id >= offset) offset = u.update_id + 1;
      if (!u.callback_query) continue;
      try {
        if (tratar(app, empresaId, token, chat, u.callback_query).tratado) tratados++;
      } catch (_) {}
    }
    if (offset !== (Number(estado.offset) || 0)) gravarJson(app, ficheiro, { offset: offset });
  }
  return { tratados: tratados };
}

// Envia uma mensagem (com botões) ao chat do administrador, se o Telegram está
// ligado e a conversa é privada. Devolve true se enviou.
function enviarComBotoes(app, empresaId, texto, acoes) {
  const avisos = require(__hooks + '/avisos.js');
  const seg = require(__hooks + '/segredos.js');
  let cfg;
  try {
    cfg = app.findFirstRecordByFilter('avisos_config', 'empresa = {:e}', { e: empresaId });
  } catch (_) {
    return false;
  }
  if (!cfg.getBool('telegram_ativo')) return false;
  const chat = cfg.getString('telegram_chat');
  const token = seg.ler(app, empresaId, 'telegram');
  if (!chat || !token) return false;
  const tec = String(chat).charAt(0) === '-' ? null : teclado(token, empresaId, acoes);
  return avisos.enviarTelegram(token, chat, texto, tec) === '';
}

// Avisa (uma vez) de cada saída por marcar que tem fim de turno previsto, com
// o botão "Saída às HH:MM".
function avisarSaidas(app) {
  let cfgs = [];
  try {
    cfgs = app.findRecordsByFilter('avisos_config', "telegram_ativo = true && telegram_chat != ''", '', 100, 0);
  } catch (_) {
    return 0;
  }
  const avisos = require(__hooks + '/avisos.js');
  const ficheiro = 'telegram_avisados.json';
  const feitos = lerJson(app, ficheiro, { chaves: {} });
  feitos.chaves = feitos.chaves || {};
  const agora = Date.now();
  for (const k in feitos.chaves) if (agora - feitos.chaves[k] > 4 * 86400000) delete feitos.chaves[k];
  let n = 0;
  for (const cfg of cfgs) {
    const empresaId = cfg.getString('empresa');
    let pend = [];
    try {
      pend = avisos.saidasPendentes(app, empresaId);
    } catch (_) {
      continue;
    }
    for (const s of pend) {
      if (!s.fimMs) continue; // sem fim previsto não há o que propor
      const chave = 'sx|' + empresaId + '|' + s.pessoa + '|' + s.entradaMs;
      if (feitos.chaves[chave]) continue;
      const alvo = s.pessoa + '~' + Math.floor(s.fimMs / 1000);
      const ok = enviarComBotoes(app, empresaId, '⏱️ Saída por marcar\n' + s.texto, [{ texto: 'Saída às ' + s.fimTexto, tipo: 'sx', id: alvo }]);
      feitos.chaves[chave] = agora; // mesmo que falhe, não insiste de minuto a minuto
      if (ok) n++;
    }
  }
  gravarJson(app, ficheiro, feitos);
  return n;
}

module.exports = { assinar, teclado, tratar, sondar, enviarComBotoes, avisarSaidas };
