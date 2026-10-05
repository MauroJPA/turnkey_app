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

// ---- HACCP: o que falta hoje (versão resumida da lógica da app)
function haccpPorFazer(app, empresaId) {
  const out = [];
  const controlos = app.findRecordsByFilter('haccp_controlos', 'empresa = {:e} && arquivado != true', 'ordem', 0, 0, { e: empresaId });
  const hoje = hojeISO();
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

// Monta o resumo; devolve { vazio, texto, html, itens }.
function montar(app, empresaId, cfg) {
  const itens = [];
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
  if (cfg.getBool('inc_haccp')) sec('HACCP por fazer', seguro(() => haccpPorFazer(app, empresaId)));
  if (cfg.getBool('inc_stock')) sec('Stock baixo', seguro(() => stockBaixo(app, empresaId)));
  if (cfg.getBool('inc_pagamentos')) sec('Pagamentos próximos', seguro(() => pagamentos(app, empresaId)));
  if (cfg.getBool('inc_faturas')) {
    const n = seguro(() => faturasPorRever(app, empresaId));
    if (n) sec('Faturas por rever', [n + ' fatura(s) à espera de confirmação']);
  }
  if (cfg.getBool('inc_precos')) sec('Preços que subiram (24 h)', seguro(() => precosSubiram(app, empresaId)));

  let nome = '';
  try {
    nome = app.findRecordById('empresas', empresaId).getString('nome');
  } catch (_) {}
  const data = hojeISO();
  const cab = 'Resumo de ' + data + (nome ? ' — ' + nome : '');
  let texto = cab + '\n';
  let html = '<h3>' + escHtml(cab) + '</h3>';
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
  return { vazio: itens.length === 0, texto: texto.trim(), html: html, itens: itens, assunto: '[gc_turnkey] ' + cab };
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

module.exports = { configDaEmpresa, montar, enviar, descrever, enviarTelegram, enviarWhatsApp, hojeISO };
