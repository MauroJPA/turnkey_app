// Avisos e resumo diário (módulo partilhado via require()).
//
// montar(): junta o que pede atenção hoje (HACCP por fazer, stock baixo,
// pagamentos próximos, faturas por rever, preços que subiram);
// enviar(): manda o resumo por email (SMTP do PocketBase) e/ou Telegram.
// WhatsApp: o código está pronto mas DESLIGADO — só funciona se existirem
// GC_TURNKEY_WHATSAPP_TOKEN e GC_TURNKEY_WHATSAPP_PHONE_ID no servidor (a API
// da Meta é paga) e não há nada na app a ativá-lo.
//
// Nunca deixar um token nem um URL com token chegar a uma mensagem de erro.

function dois(n) {
  return n < 10 ? '0' + n : '' + n;
}

function hojeISO(d) {
  d = d || new Date();
  return d.getFullYear() + '-' + dois(d.getMonth() + 1) + '-' + dois(d.getDate());
}

// ---- dias de trabalho da empresa (1 = segunda … 7 = domingo; vazio = todos)
function diasDeTrabalho(app, empresaId) {
  let txt = '';
  try {
    txt = app.findFirstRecordByFilter('configuracoes_custo', 'empresa = {:e}', { e: empresaId }).getString('dias_trabalho');
  } catch (_) {}
  const dias = String(txt || '')
    .split(',')
    .map((s) => parseInt(s.trim(), 10))
    .filter((n) => n >= 1 && n <= 7);
  return dias.length ? dias : [1, 2, 3, 4, 5, 6, 7];
}

function abertoNesse(dias, d) {
  const w = d.getDay() === 0 ? 7 : d.getDay();
  return dias.indexOf(w) >= 0;
}

// A data (AAAA-MM-DD) ou, se a empresa fecha nesse dia, o primeiro dia aberto a seguir.
function proximoAberto(iso, dias) {
  const d = new Date(iso + 'T12:00:00');
  for (let i = 0; i < 7 && !abertoNesse(dias, d); i++) d.setDate(d.getDate() + 1);
  return hojeISO(d);
}

// Quem está ausente hoje (férias, baixa, falta aprovadas).
function ausentesHoje(app, empresaId) {
  const hoje = hojeISO();
  const regs = app.findRecordsByFilter(
    'ferias',
    "empresa = {:e} && estado = 'aprovado' && data_inicio <= {:fim} && data_fim >= {:ini}",
    '',
    50,
    0,
    { e: empresaId, fim: hoje + ' 23:59:59.999Z', ini: hoje + ' 00:00:00.000Z' },
  );
  const out = [];
  for (const r of regs) {
    const fim = String(r.getString('data_fim')).substring(0, 10);
    if (fim < hoje) continue;
    // só se diz "de férias"; baixas e faltas são dados pessoais: "ausente"
    out.push(r.getString('nome') + (r.getString('tipo') === 'ferias' ? ' (férias)' : ' (ausente)'));
  }
  return out;
}

// O Vendus está ligado mas deixou de sincronizar (a última sincronização que
// correu bem foi há mais de 26 horas).
function vendusAtrasado(app, empresaId) {
  let configurado = false;
  try {
    configurado = !!require(__hooks + '/segredos.js').ler(app, empresaId, 'vendus');
  } catch (_) {}
  if (!configurado) return [];
  const emp = app.findRecordById('empresas', empresaId);
  const ok = emp.getString('vendus_ok_em');
  const horas = ok ? (Date.now() - new Date(ok).getTime()) / 3600000 : 9999;
  if (horas <= 26) return [];
  const quando = ok ? 'a última sincronização que correu bem foi há ' + Math.round(horas) + ' h' : 'ainda não sincronizou';
  const motivo = emp.getString('vendus_resultado');
  return ['Vendus: ' + quando + (motivo ? ' (' + motivo + ')' : '') + ' — a previsão e as vendas podem estar desatualizadas.'];
}

// Lotes com a validade a acabar: ingredientes (5 dias) e produtos (hoje/amanhã).
function validadesAAcabar(app, empresaId) {
  const out = [];
  const dia = (d) => hojeISO(d);
  const mais = (n) => {
    const d = new Date();
    d.setDate(d.getDate() + n);
    return dia(d);
  };
  const hoje = hojeISO();
  const limiteMax = (iso) => iso + ' 23:59:59.999Z';
  const quando = (iso) => {
    const dias = Math.round((new Date(iso + 'T12:00:00').getTime() - new Date(hoje + 'T12:00:00').getTime()) / 86400000);
    if (dias === 0) return 'vence hoje';
    if (dias === 1) return 'vence amanhã';
    if (dias < 0) return 'vencido há ' + -dias + (dias === -1 ? ' dia' : ' dias');
    return 'vence em ' + dias + ' dias';
  };
  const antigo = mais(-14);
  const ings = app.findRecordsByFilter(
    'lotes_ingrediente',
    "empresa = {:e} && esgotado != true && validade != '' && validade <= {:l} && validade >= {:a}",
    'validade',
    30,
    0,
    { e: empresaId, l: limiteMax(mais(5)), a: antigo + ' 00:00:00.000Z' },
  );
  for (const r of ings) {
    let nome = 'Ingrediente';
    try {
      nome = app.findRecordById('ingredientes', r.getString('ingrediente')).getString('nome');
    } catch (_) {}
    const v = String(r.getString('validade')).substring(0, 10);
    out.push(nome + ' · lote ' + r.getString('lote') + ' — ' + quando(v));
  }
  const prods = app.findRecordsByFilter(
    'lotes_producao',
    "empresa = {:e} && esgotado != true && quantidade > 0 && validade != '' && validade <= {:l} && validade >= {:a}",
    'validade',
    30,
    0,
    { e: empresaId, l: limiteMax(mais(1)), a: antigo + ' 00:00:00.000Z' },
  );
  for (const r of prods) {
    const v = String(r.getString('validade')).substring(0, 10);
    out.push(r.getString('ficha_nome') + ' · lote ' + r.getString('codigo') + ' (' + Math.round(r.getFloat('quantidade')) + ' un) — ' + quando(v));
  }
  return out;
}

// Quem entrou e ainda não marcou a saída: sem saída há mais de 16 h ou, se a
// escala diz quando o turno acaba, mais de 60 min depois do fim.
function saidasPorMarcar(app, empresaId) {
  const agora = new Date();
  const desde = new Date(agora.getTime() - 72 * 3600 * 1000).toISOString().replace('T', ' ');
  const regs = app.findRecordsByFilter('ponto_registos', 'empresa = {:e} && data_hora >= {:d}', '-data_hora', 2000, 0, { e: empresaId, d: desde });
  const vistos = {};
  const out = [];
  const hm = (d) => dois(d.getHours()) + ':' + dois(d.getMinutes());
  for (const r of regs) {
    const p = r.getString('pessoa');
    if (vistos[p]) continue;
    vistos[p] = true;
    if (r.getString('tipo') === 'saida') continue;
    const quando = new Date(String(r.getString('data_hora')).replace(' ', 'T'));
    const horas = (agora.getTime() - quando.getTime()) / 3600000;
    // o fim previsto do turno desse dia
    let fim = null;
    try {
      const iso = hojeISO(quando);
      let ini = '';
      let f = '';
      let folga = false;
      try {
        const ex = app.findFirstRecordByFilter('escala_excecoes', 'empresa = {:e} && pessoa = {:p} && data = {:d}', { e: empresaId, p: p, d: iso + ' 00:00:00.000Z' });
        folga = ex.getBool('folga');
        ini = ex.getString('inicio');
        f = ex.getString('fim');
      } catch (_) {
        const dow = quando.getDay() === 0 ? 7 : quando.getDay();
        try {
          const m = app.findFirstRecordByFilter('escala_modelo', 'empresa = {:e} && pessoa = {:p} && dia_semana = {:w}', { e: empresaId, p: p, w: dow });
          ini = m.getString('inicio');
          f = m.getString('fim');
        } catch (_) {}
      }
      const mi = /^(\d{2}):(\d{2})$/.exec(ini);
      const mf = /^(\d{2}):(\d{2})$/.exec(f);
      if (!folga && mi && mf) {
        fim = new Date(quando.getFullYear(), quando.getMonth(), quando.getDate(), parseInt(mf[1], 10), parseInt(mf[2], 10));
        if (parseInt(mf[1], 10) * 60 + parseInt(mf[2], 10) <= parseInt(mi[1], 10) * 60 + parseInt(mi[2], 10)) fim.setDate(fim.getDate() + 1);
      }
    } catch (_) {}
    const passou = horas > 16 || (fim && agora.getTime() > fim.getTime() + 3600000);
    if (!passou) continue;
    const mesmoDia = hojeISO(quando) === hojeISO(agora);
    out.push(
      (r.getString('nome') || 'Sem nome') +
        ' — entrada ' + (mesmoDia ? '' : quando.getDate() + '/' + (quando.getMonth() + 1) + ' ') + 'às ' + hm(quando) +
        (fim ? ' (turno até ' + hm(fim) + ')' : ''),
    );
  }
  return out;
}

// ---- HACCP: o que falta hoje (versão resumida da lógica da app)
function haccpPorFazer(app, empresaId, dias) {
  const out = [];
  const controlos = app.findRecordsByFilter('haccp_controlos', 'empresa = {:e} && arquivado != true', 'ordem', 0, 0, { e: empresaId });
  const hoje = hojeISO();
  dias = dias || [1, 2, 3, 4, 5, 6, 7];
  for (const c of controlos) {
    const per = Math.round(c.getFloat('periodicidade_dias'));
    if (per === 0) continue; // ocasional
    const esperados = per === 1 ? Math.max(1, Math.round(c.getFloat('vezes_por_dia')) || 1) : 1;
    const regs = app.findRecordsByFilter('haccp_registos', 'controlo = {:c}', '-data_hora', 30, 0, { c: c.id });
    if (regs.length === 0) {
      out.push(c.getString('nome') + ' (nunca registado)');
      continue;
    }
    const ultimo = regs[0];
    const dUlt = String(ultimo.getString('data_hora')).substring(0, 10);
    if (per === 1) {
      let feitos = 0;
      for (const r of regs) {
        if (String(r.getString('data_hora')).substring(0, 10) === hoje) feitos++;
      }
      if (feitos < esperados) out.push(c.getString('nome') + (esperados > 1 ? ' (' + feitos + ' de ' + esperados + ')' : ''));
    } else {
      let prox = String(ultimo.getString('proximo_vencimento') || '').substring(0, 10);
      if (!prox) {
        const dt = new Date(dUlt + 'T12:00:00');
        dt.setDate(dt.getDate() + per);
        prox = hojeISO(dt);
      }
      // se o prazo cai num dia de folga, passa para o primeiro dia aberto
      prox = proximoAberto(prox, dias);
      if (prox <= hoje) out.push(c.getString('nome') + (prox < hoje ? ' (atrasado)' : ' (vence hoje)'));
    }
  }
  return out;
}

function stockBaixo(app, empresaId) {
  const out = [];
  const regs = app.findRecordsByFilter('inventario', 'empresa = {:e} && minimo > 0 && quantidade < minimo', '', 50, 0, { e: empresaId });
  for (const r of regs) {
    let nome = '';
    try {
      if (r.getString('ingrediente')) nome = app.findRecordById('ingredientes', r.getString('ingrediente')).getString('nome');
      else if (r.getString('ficha')) nome = app.findRecordById('fichas_tecnicas', r.getString('ficha')).getString('nome');
    } catch (_) {}
    if (nome) out.push(nome);
  }
  return out;
}

function pagamentos(app, empresaId) {
  const out = [];
  const hoje = new Date();
  const custos = app.findRecordsByFilter('custos_fixos', 'empresa = {:e} && dia_pagamento > 0', '', 100, 0, { e: empresaId });
  for (const c of custos) {
    if (c.getBool('arquivado')) continue;
    const dia = Math.round(c.getFloat('dia_pagamento'));
    let dias = dia - hoje.getDate();
    if (dias < 0) {
      const ult = new Date(hoje.getFullYear(), hoje.getMonth() + 1, 0).getDate();
      dias = ult - hoje.getDate() + dia;
    }
    if (dias <= 7) out.push(c.getString('nome') + (dias === 0 ? ' (hoje)' : ' (em ' + dias + ' d)'));
  }
  return out;
}

function faturasPorRever(app, empresaId) {
  const n = app.countRecords('faturas', $dbx.exp('empresa = {:e} && estado = {:s}', { e: empresaId, s: 'analisada' }));
  return n;
}

function precosSubiram(app, empresaId) {
  const out = [];
  let limiar = 5;
  try {
    const cfg = app.findFirstRecordByFilter('configuracoes_custo', 'empresa = {:e}', { e: empresaId });
    limiar = cfg.getFloat('alerta_preco_pct') || 5;
  } catch (_) {}
  const desde = new Date(Date.now() - 24 * 3600 * 1000).toISOString().replace('T', ' ');
  const regs = app.findRecordsByFilter('variacoes_preco', 'empresa = {:e} && created >= {:d} && pct >= {:p}', '-pct', 10, 0, { e: empresaId, d: desde, p: limiar });
  for (const r of regs) out.push(r.getString('ingrediente_nome') + ' +' + Math.round(r.getFloat('pct')) + '%');
  return out;
}

// Monta o resumo; devolve { vazio, texto, html, itens, fechado }.
// `fechado`: hoje a empresa não trabalha (o envio automático salta esse dia).
function montar(app, empresaId, cfg) {
  const itens = [];
  const dias = diasDeTrabalho(app, empresaId);
  const fechado = !abertoNesse(dias, new Date());
  const sec = (titulo, linhas) => {
    if (linhas && linhas.length) itens.push({ titulo: titulo, linhas: linhas });
  };
  const seguro = (fn) => {
    try {
      return fn();
    } catch (err) {
      console.log('[avisos] ' + err);
      return null;
    }
  };
  if (cfg.getBool('inc_haccp')) sec('HACCP por fazer', seguro(() => haccpPorFazer(app, empresaId, dias)));
  if (cfg.getBool('inc_stock')) sec('Stock baixo', seguro(() => stockBaixo(app, empresaId)));
  if (cfg.getBool('inc_pagamentos')) sec('Pagamentos próximos', seguro(() => pagamentos(app, empresaId)));
  if (cfg.getBool('inc_faturas')) {
    const n = seguro(() => faturasPorRever(app, empresaId));
    if (n) sec('Faturas por rever', [n + ' fatura(s) à espera de confirmação']);
  }
  if (cfg.getBool('inc_precos')) sec('Preços que subiram (24 h)', seguro(() => precosSubiram(app, empresaId)));
  sec('Ausentes hoje', seguro(() => ausentesHoje(app, empresaId)));
  sec('Saída por marcar', seguro(() => saidasPorMarcar(app, empresaId)));
  sec('Validades a acabar', seguro(() => validadesAAcabar(app, empresaId)));
  sec('Vendus sem sincronizar', seguro(() => vendusAtrasado(app, empresaId)));

  let nome = '';
  try {
    nome = app.findRecordById('empresas', empresaId).getString('nome');
  } catch (_) {}
  const data = hojeISO();
  const cab = 'Resumo de ' + data + (nome ? ' — ' + nome : '');
  let texto = cab + '\n';
  let html = '<h3>' + escHtml(cab) + '</h3>';
  if (fechado) {
    texto += '\n(Hoje é dia de folga: o resumo automático não é enviado.)\n';
    html += '<p><i>Hoje é dia de folga: o resumo automático não é enviado.</i></p>';
  }
  if (itens.length === 0) {
    texto += '\nTudo em dia: nada a pedir atenção. ✅';
    html += '<p>Tudo em dia: nada a pedir atenção. ✅</p>';
  }
  for (const it of itens) {
    texto += '\n' + it.titulo + ':\n';
    html += '<p><b>' + escHtml(it.titulo) + '</b></p><ul>';
    for (const l of it.linhas) {
      texto += '• ' + l + '\n';
      html += '<li>' + escHtml(l) + '</li>';
    }
    html += '</ul>';
  }
  return { vazio: itens.length === 0, texto: texto.trim(), html: html, itens: itens, fechado: fechado, assunto: '[gc_turnkey] ' + cab };
}

function escHtml(s) {
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

// ---- envio
function enviarEmail(app, para, resumo) {
  const smtp = app.settings().smtp;
  if (!smtp || !smtp.enabled) {
    return 'SMTP não configurado no PocketBase (Definições → Mail). Usa o Telegram ou configura o email do servidor.';
  }
  const meta = app.settings().meta;
  const lista = String(para || '')
    .split(/[,;\s]+/)
    .map((s) => s.trim())
    .filter((s) => /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(s))
    .slice(0, 5);
  if (!lista.length) return 'Sem endereços de email válidos.';
  try {
    const msg = new MailerMessage({
      from: { address: meta.senderAddress, name: meta.senderName },
      to: lista.map((a) => ({ address: a })),
      subject: resumo.assunto,
      html: resumo.html,
    });
    app.newMailClient().send(msg);
    return '';
  } catch (err) {
    return 'Falhou o envio do email.';
  }
}

function enviarTelegram(token, chat, texto) {
  if (!token) return 'Falta o token do bot do Telegram.';
  if (!chat) return 'Falta o chat do Telegram.';
  try {
    const r = $http.send({
      url: ($os.getenv('GC_TURNKEY_TELEGRAM_URL') || 'https://api.telegram.org') + '/bot' + token + '/sendMessage',
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ chat_id: String(chat), text: String(texto).substring(0, 3800), disable_web_page_preview: true }),
      timeout: 20,
    });
    if (r.statusCode !== 200) {
      return r.statusCode === 401 ? 'O token do bot é inválido.' : r.statusCode === 400 || r.statusCode === 403 ? 'O Telegram recusou: confirma o chat e que falaste com o bot (envia /start).' : 'O Telegram devolveu um erro (' + r.statusCode + ').';
    }
    return '';
  } catch (_) {
    return 'Não consegui contactar o Telegram.';
  }
}

// Desligado por omissão (API paga); só com variáveis de ambiente.
function enviarWhatsApp(numero, texto) {
  const token = $os.getenv('GC_TURNKEY_WHATSAPP_TOKEN') || '';
  const phoneId = $os.getenv('GC_TURNKEY_WHATSAPP_PHONE_ID') || '';
  if (!token || !phoneId) return 'WhatsApp desligado.';
  try {
    const r = $http.send({
      url: 'https://graph.facebook.com/v20.0/' + phoneId + '/messages',
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + token },
      body: JSON.stringify({ messaging_product: 'whatsapp', to: String(numero), type: 'text', text: { body: String(texto).substring(0, 3800) } }),
      timeout: 20,
    });
    return r.statusCode >= 200 && r.statusCode < 300 ? '' : 'O WhatsApp devolveu um erro (' + r.statusCode + ').';
  } catch (_) {
    return 'Não consegui contactar o WhatsApp.';
  }
}

// Envia para os canais ligados; devolve { email, telegram } com '' = enviado.
function enviar(app, empresaId, cfg, resumo, ler) {
  const res = {};
  if (cfg.getBool('email_ativo')) res.email = enviarEmail(app, cfg.getString('email_para'), resumo);
  if (cfg.getBool('telegram_ativo')) {
    res.telegram = enviarTelegram(ler(app, empresaId, 'telegram'), cfg.getString('telegram_chat'), resumo.texto);
  }
  return res;
}

function descrever(res) {
  const partes = [];
  for (const k in res) partes.push(k + ': ' + (res[k] === '' ? 'enviado' : res[k]));
  return partes.join(' · ') || 'nenhum canal ligado';
}

// A configuração gravada da empresa, ou uma em memória (tudo incluído, sem canais).
function configDaEmpresa(app, empresaId) {
  try {
    return app.findFirstRecordByFilter('avisos_config', 'empresa = {:e}', { e: empresaId });
  } catch (_) {
    const r = new Record(app.findCollectionByNameOrId('avisos_config'));
    r.set('empresa', empresaId);
    for (const f of ['inc_haccp', 'inc_stock', 'inc_pagamentos', 'inc_faturas', 'inc_precos']) r.set(f, true);
    return r;
  }
}

module.exports = { configDaEmpresa, montar, enviar, descrever, enviarTelegram, enviarWhatsApp, hojeISO, diasDeTrabalho, abertoNesse, proximoAberto };
