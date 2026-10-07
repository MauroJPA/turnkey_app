// Lógica do vigia de segurança no PocketBase (módulo partilhado via require()).
// Lê o que o script do servidor escreveu; nunca executa nada nem devolve
// caminhos ou segredos.

const FICHEIRO = 'seguranca_vigia.json';
const ACKS = 'seguranca_acks.json';
const AVISADOS = 'seguranca_avisados.json';
const MAX_IDADE_S = 40 * 60; // o vigia corre de 10 em 10 min: 40 min sem dados = parou

function ler(app, nome) {
  try {
    return JSON.parse(toString($os.readFile(String(app.dataDir()) + '/' + nome)));
  } catch (_) {
    return null;
  }
}

function gravar(app, nome, obj) {
  $os.writeFile(String(app.dataDir()) + '/' + nome, JSON.stringify(obj), 0o644);
}

function limpar(s, n) {
  return String(s === undefined || s === null ? '' : s).substring(0, n);
}

// O estado para a app (campos limitados e já sem nada interno).
function estado(app) {
  const j = ler(app, FICHEIRO);
  if (!j || typeof j !== 'object') return { operador: true, instalado: false };
  const agora = Math.floor(Date.now() / 1000);
  const idade = Math.max(0, agora - (Number(j.quando) || 0));
  const acks = ler(app, ACKS) || { ids: [] };
  const pendentes = {};
  for (const a of acks.ids || []) pendentes[limpar(a.id, 300)] = true;
  const achados = [];
  for (const a of Array.isArray(j.achados) ? j.achados.slice(0, 60) : []) {
    achados.push({
      id: limpar(a.id, 300),
      gravidade: ['critico', 'atencao', 'info'].indexOf(a.gravidade) >= 0 ? a.gravidade : 'info',
      categoria: limpar(a.categoria, 30),
      titulo: limpar(a.titulo, 200),
      detalhe: limpar(a.detalhe, 400),
      fazer: limpar(a.fazer, 700),
      desde: Number(a.desde) || 0,
      vezes: Number(a.vezes) || 0,
      itens: (Array.isArray(a.itens) ? a.itens : []).slice(0, 12).map((x) => limpar(x, 160)),
      aceite: !!pendentes[limpar(a.id, 300)],
    });
  }
  const verif = {};
  for (const k in j.verificacoes || {}) {
    const v = j.verificacoes[k] || {};
    verif[limpar(k, 30)] = { ok: v.ok === true, quando: Number(v.quando) || 0 };
  }
  return {
    operador: true,
    instalado: true,
    estado: ['ok', 'atencao', 'critico'].indexOf(j.estado) >= 0 ? j.estado : 'ok',
    pontuacao: Number(j.pontuacao) || 0,
    quando: Number(j.quando) || 0,
    idade: idade,
    parado: idade > MAX_IDADE_S,
    achados: achados,
    verificacoes: verif,
    notas: (Array.isArray(j.notas) ? j.notas : []).slice(0, 5).map((x) => limpar(x, 200)),
  };
}

// "Já verifiquei": pede ao vigia para aprender este alerta como normal.
function aceitar(app, id, quem) {
  const j = ler(app, FICHEIRO);
  const existe = j && Array.isArray(j.achados) && j.achados.some((a) => a.id === id);
  if (!existe) return { ok: false, mensagem: 'Esse alerta já não existe.' };
  const acks = ler(app, ACKS) || { ids: [] };
  acks.ids = (acks.ids || []).slice(-200);
  acks.ids.push({ id: id, quando: new Date().toISOString(), por: limpar(quem, 80) });
  gravar(app, ACKS, acks);
  return { ok: true };
}

// A empresa do dono do servidor (a que recebe os avisos de segurança).
function empresaDoDono(app) {
  const lista = String($os.getenv('GC_TURNKEY_OPERADORES') || '')
    .toLowerCase()
    .split(',')
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
  try {
    if (lista.length > 0) {
      for (const email of lista) {
        const us = app.findRecordsByFilter('users', 'email = {:e} && aprovado = true', '', 1, 0, { e: email });
        if (us.length > 0 && us[0].getString('empresa')) return us[0].getString('empresa');
      }
      return '';
    }
    const donos = app.findRecordsByFilter('users', "papel = 'owner' && aprovado = true", 'created', 1, 0);
    return donos.length > 0 ? donos[0].getString('empresa') : '';
  } catch (_) {
    return '';
  }
}

// Linhas para o resumo diário do dono: alertas ativos (críticos e de atenção).
function linhasParaResumo(app, empresaId) {
  if (!empresaId || empresaDoDono(app) !== empresaId) return [];
  const e = estado(app);
  if (!e.instalado) return [];
  const out = [];
  if (e.parado) out.push('O vigia de segurança não corre há mais de 40 minutos: confirma o servidor.');
  for (const a of e.achados) {
    if (a.gravidade === 'info' || a.aceite) continue;
    out.push((a.gravidade === 'critico' ? 'URGENTE: ' : '') + a.titulo + (a.detalhe ? ' — ' + a.detalhe : ''));
  }
  return out.slice(0, 8);
}

function escHtml(s) {
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

// Cron: avisa UMA vez de cada alerta novo (e se o vigia parar).
function avisarNovos(app) {
  const e = estado(app);
  if (!e.instalado) return;
  const avisados = ler(app, AVISADOS) || { ids: {}, parado: false };
  avisados.ids = avisados.ids || {};
  const novos = [];
  const ativos = {};
  for (const a of e.achados) {
    if (a.gravidade === 'info') continue;
    ativos[a.id] = true;
    if (!avisados.ids[a.id] && !a.aceite) novos.push(a);
  }
  const parouAgora = e.parado && !avisados.parado;
  if (novos.length === 0 && !parouAgora) {
    // limpa o que já passou, para voltar a avisar se reaparecer
    let mudou = false;
    for (const k in avisados.ids) {
      if (!ativos[k]) {
        delete avisados.ids[k];
        mudou = true;
      }
    }
    if (!e.parado && avisados.parado) {
      avisados.parado = false;
      mudou = true;
    }
    if (mudou) gravar(app, AVISADOS, avisados);
    return;
  }

  const linhas = [];
  if (parouAgora) linhas.push('O vigia de segurança deixou de correr (sem dados há mais de 40 minutos).');
  for (const a of novos.slice(0, 8)) {
    linhas.push((a.gravidade === 'critico' ? '🚨 ' : '⚠️ ') + a.titulo + (a.detalhe ? ' — ' + a.detalhe : ''));
  }
  const critico = novos.some((a) => a.gravidade === 'critico') || parouAgora;
  const texto = '🔐 Segurança do servidor\n' + linhas.join('\n') + '\nAbre a app: Configurações → Segurança e backups.';
  const html =
    '<h3>Segurança do servidor</h3><ul>' +
    linhas.map((l) => '<li>' + escHtml(l) + '</li>').join('') +
    '</ul><p>Abre a app: Configurações → Segurança e backups.</p>';
  const resumo = {
    texto: texto,
    html: html,
    assunto: (critico ? '[URGENTE] ' : '') + '[gc_turnkey] Alerta de segurança do servidor',
  };

  let enviado = false;
  const empresaId = empresaDoDono(app);
  if (empresaId) {
    try {
      const avisos = require(`${__hooks}/avisos.js`);
      const seg = require(`${__hooks}/segredos.js`);
      const cfg = avisos.configDaEmpresa(app, empresaId);
      const res = avisos.enviar(app, empresaId, cfg, resumo, seg.ler);
      for (const k in res) if (res[k] === '') enviado = true;
    } catch (err) {
      console.log('[vigia] não consegui enviar: ' + String(err && err.message ? err.message : 'desconhecido'));
    }
  }
  // Mesmo sem canais ligados, não repete de 5 em 5 minutos: fica visível na app.
  for (const a of novos) avisados.ids[a.id] = Math.floor(Date.now() / 1000);
  if (parouAgora) avisados.parado = true;
  avisados.ultimo = { quando: new Date().toISOString(), enviado: enviado };
  gravar(app, AVISADOS, avisados);
}

module.exports = { estado, aceitar, linhasParaResumo, avisarNovos, empresaDoDono };
