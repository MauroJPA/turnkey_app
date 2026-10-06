// Resumo semanal para o proprietário (módulo partilhado via require()).
//
// Junta numa só mensagem como correu a semana passada (segunda a domingo):
// vendas (face à semana anterior), margem sobre a matéria-prima, desperdício em
// euros (o evitável à parte), horas da equipa, preços que subiram e o que pede
// atenção nos próximos dias (ausências, formações a caducar).
//
// Devolve o mesmo formato do resumo diário: { texto, html, assunto, itens }.
// Nunca deixar um token nem um URL com token chegar a uma mensagem.

function dois(n) {
  return n < 10 ? '0' + n : '' + n;
}

function iso(d) {
  return d.getFullYear() + '-' + dois(d.getMonth() + 1) + '-' + dois(d.getDate());
}

function mais(d, n) {
  const x = new Date(d.getFullYear(), d.getMonth(), d.getDate() + n);
  return x;
}

// A última semana completa (segunda a domingo) antes de `hoje`.
function ultimaSemana(hoje) {
  const h = new Date(hoje.getFullYear(), hoje.getMonth(), hoje.getDate());
  const dow = h.getDay() === 0 ? 7 : h.getDay(); // 1 = segunda ... 7 = domingo
  const domingo = mais(h, -dow);
  return { de: mais(domingo, -6), ate: domingo };
}

function inicio(d) {
  return iso(d) + ' 00:00:00.000Z';
}

function fim(d) {
  return iso(d) + ' 23:59:59.999Z';
}

function eur(v) {
  return '€' + (Math.round(v * 100) / 100).toFixed(2).replace('.', ',');
}

function pct(v) {
  return (v >= 0 ? '+' : '−') + Math.abs(Math.round(v)) + ' %';
}

function horasTexto(h) {
  return (Math.round(h * 10) / 10).toString().replace('.', ',') + ' h';
}

function ivaDaEmpresa(app, empresaId) {
  try {
    const cfg = app.findFirstRecordByFilter('configuracoes_custo', 'empresa = {:e}', { e: empresaId });
    return cfg.getFloat('iva_vendas') || 0;
  } catch (_) {
    return 0;
  }
}

// Total vendido (com IVA) e custo de matéria-prima do que se vendeu.
function vendasDe(app, empresaId, de, ate, fichaCusto) {
  const vendas = app.findRecordsByFilter('vendas', 'empresa = {:e} && data >= {:d} && data <= {:a}', '', 0, 0, {
    e: empresaId,
    d: inicio(de),
    a: fim(ate),
  });
  let total = 0;
  const ids = [];
  for (const v of vendas) {
    total += v.getFloat('total');
    ids.push(v.id);
  }
  let custo = 0;
  let comCusto = 0;
  // as linhas das vendas, em blocos (o filtro tem limite de tamanho)
  for (let i = 0; i < ids.length; i += 40) {
    const bloco = ids.slice(i, i + 40);
    const params = { e: empresaId };
    const partes = bloco.map((id, k) => {
      params['v' + k] = id;
      return 'venda = {:v' + k + '}';
    });
    const itens = app.findRecordsByFilter('vendas_itens', 'empresa = {:e} && (' + partes.join(' || ') + ')', '', 0, 0, params);
    for (const it of itens) {
      const q = it.getFloat('quantidade');
      let c = it.getFloat('custo_unitario_snapshot');
      if (!(c > 0)) c = fichaCusto[it.getString('ficha')] || 0;
      if (c > 0) {
        custo += q * c;
        comCusto += it.getFloat('total_linha') || q * it.getFloat('preco_unitario');
      }
    }
  }
  return { total: total, pedidos: vendas.length, custo: custo, vendidoComCusto: comCusto };
}

function custosDasFichas(app, empresaId) {
  const m = {};
  try {
    const fichas = app.findRecordsByFilter('fichas_tecnicas', 'empresa = {:e}', '', 0, 0, { e: empresaId });
    for (const f of fichas) m[f.id] = f.getFloat('custo_produto');
  } catch (_) {}
  return m;
}

function linhasVendas(app, empresaId, sem, ant, iva, fichaCusto) {
  const a = vendasDe(app, empresaId, sem.de, sem.ate, fichaCusto);
  const b = vendasDe(app, empresaId, ant.de, ant.ate, fichaCusto);
  if (a.total <= 0 && b.total <= 0) return [];
  const out = [];
  let l = 'Vendas: ' + eur(a.total) + ' em ' + a.pedidos + ' ' + (a.pedidos === 1 ? 'venda' : 'vendas');
  if (b.total > 0) l += ' (' + pct(((a.total - b.total) / b.total) * 100) + ' face à semana anterior, ' + eur(b.total) + ')';
  else l += ' (sem vendas na semana anterior)';
  out.push(l);
  if (a.custo > 0 && a.vendidoComCusto > 0) {
    // margem sobre a parte das vendas que tem custo conhecido, sem IVA
    const semIva = a.vendidoComCusto / (1 + iva / 100);
    const margem = semIva - a.custo;
    out.push('Margem sobre a matéria-prima: ' + eur(margem) + ' (' + Math.round((margem / semIva) * 100) + ' % das vendas sem IVA)');
  }
  return out;
}

function linhasDesperdicio(app, empresaId, sem, fichaCusto) {
  const regs = app.findRecordsByFilter('movimentos_produto', "empresa = {:e} && tipo = 'desperdicio' && data >= {:d} && data <= {:a}", '', 0, 0, {
    e: empresaId,
    d: inicio(sem.de),
    a: fim(sem.ate),
  });
  if (!regs.length) return [];
  const evitaveis = { queimado: 1, fora_prazo: 1, quebrado: 1, erro_producao: 1 };
  const nomes = { queimado: 'queimado', fora_prazo: 'fora do prazo', quebrado: 'quebrado', erro_producao: 'erro de produção' };
  let total = 0;
  let evit = 0;
  let unidades = 0;
  const porMotivo = {};
  for (const r of regs) {
    const q = r.getFloat('quantidade');
    const c = q * (fichaCusto[r.getString('ficha')] || 0);
    unidades += q;
    total += c;
    const m = r.getString('motivo');
    if (evitaveis[m]) {
      evit += c;
      porMotivo[m] = (porMotivo[m] || 0) + c;
    }
  }
  const out = ['Desperdício: ' + Math.round(unidades) + ' un · ' + eur(total) + (evit > 0 ? ' (evitável: ' + eur(evit) + ')' : '')];
  let pior = '';
  let max = 0;
  for (const m in porMotivo) {
    if (porMotivo[m] > max) {
      max = porMotivo[m];
      pior = m;
    }
  }
  if (pior) out.push('A perda evitável que mais custou: ' + nomes[pior] + ' (' + eur(max) + ')');
  return out;
}

// Horas trabalhadas na semana (entrada → pausas → saída), por pessoa.
function linhasHoras(app, empresaId, sem) {
  // um dia antes para apanhar turnos que começaram na véspera
  const regs = app.findRecordsByFilter('ponto_registos', 'empresa = {:e} && data_hora >= {:d} && data_hora <= {:a}', 'data_hora', 5000, 0, {
    e: empresaId,
    d: inicio(mais(sem.de, -1)),
    a: fim(mais(sem.ate, 1)),
  });
  if (!regs.length) return [];
  const desde = new Date(sem.de.getFullYear(), sem.de.getMonth(), sem.de.getDate()).getTime();
  const ate = new Date(sem.ate.getFullYear(), sem.ate.getMonth(), sem.ate.getDate() + 1).getTime();
  const porPessoa = {};
  const nomes = {};
  const estado = {};
  for (const r of regs) {
    const p = r.getString('pessoa');
    nomes[p] = r.getString('nome') || nomes[p] || 'Pessoa';
    const t = new Date(String(r.getString('data_hora')).replace(' ', 'T')).getTime();
    const e = (estado[p] = estado[p] || { entrada: null, pausa: 0, pausaDesde: null });
    const tipo = r.getString('tipo');
    if (tipo === 'entrada') {
      e.entrada = t;
      e.pausa = 0;
      e.pausaDesde = null;
    } else if (tipo === 'pausa_inicio' && e.entrada !== null && e.pausaDesde === null) {
      e.pausaDesde = t;
    } else if (tipo === 'pausa_fim' && e.pausaDesde !== null) {
      e.pausa += t - e.pausaDesde;
      e.pausaDesde = null;
    } else if (tipo === 'saida' && e.entrada !== null) {
      if (e.pausaDesde !== null) {
        e.pausa += t - e.pausaDesde;
        e.pausaDesde = null;
      }
      const dur = t - e.entrada - e.pausa;
      // a jornada conta na semana em que começou; ignora absurdos (> 16 h)
      if (dur > 0 && dur <= 16 * 3600000 && e.entrada >= desde && e.entrada < ate) {
        porPessoa[p] = (porPessoa[p] || 0) + dur / 3600000;
      }
      e.entrada = null;
    }
  }
  const lista = Object.keys(porPessoa)
    .map((p) => ({ nome: nomes[p], h: porPessoa[p] }))
    .sort((a, b) => b.h - a.h);
  if (!lista.length) return [];
  const total = lista.reduce((s, x) => s + x.h, 0);
  const out = ['Horas da equipa: ' + horasTexto(total) + ' (' + lista.length + ' ' + (lista.length === 1 ? 'pessoa' : 'pessoas') + ')'];
  out.push(
    lista
      .slice(0, 8)
      .map((x) => x.nome + ' ' + horasTexto(x.h))
      .join(' · '),
  );
  return out;
}

function linhasPrecos(app, empresaId, hoje) {
  let limiar = 5;
  try {
    const cfg = app.findFirstRecordByFilter('configuracoes_custo', 'empresa = {:e}', { e: empresaId });
    limiar = cfg.getFloat('alerta_preco_pct') || 5;
  } catch (_) {}
  const desde = new Date(hoje.getTime() - 7 * 24 * 3600 * 1000).toISOString().replace('T', ' ');
  const regs = app.findRecordsByFilter('variacoes_preco', 'empresa = {:e} && created >= {:d} && pct >= {:p}', '-pct', 8, 0, {
    e: empresaId,
    d: desde,
    p: limiar,
  });
  return regs.map((r) => r.getString('ingrediente_nome') + ' +' + Math.round(r.getFloat('pct')) + ' %');
}

// Quem estará fora na próxima semana (segunda a domingo seguintes).
function linhasProximaSemana(app, empresaId, hoje) {
  const h = new Date(hoje.getFullYear(), hoje.getMonth(), hoje.getDate());
  const dow = h.getDay() === 0 ? 7 : h.getDay();
  const seg = mais(h, 8 - dow); // próxima segunda
  const dom = mais(seg, 6);
  const regs = app.findRecordsByFilter(
    'ferias',
    "empresa = {:e} && estado = 'aprovado' && data_inicio <= {:a} && data_fim >= {:d}",
    'data_inicio',
    20,
    0,
    { e: empresaId, d: inicio(seg), a: fim(dom) },
  );
  const out = [];
  const dm = (s) => {
    const x = String(s).substring(0, 10).split('-');
    return x[2] + '/' + x[1];
  };
  for (const r of regs) {
    // só se diz "férias"; baixas e faltas são dados pessoais: "ausente"
    out.push(r.getString('nome') + (r.getString('tipo') === 'ferias' ? ' (férias' : ' (ausente') + ' ' + dm(r.getString('data_inicio')) + '–' + dm(r.getString('data_fim')) + ')');
  }
  return out;
}

function escHtml(s) {
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

// Monta o resumo da última semana completa. `hoje` só existe para os testes.
function montar(app, empresaId, hoje) {
  const agora = hoje || new Date();
  const sem = ultimaSemana(agora);
  const ant = { de: mais(sem.de, -7), ate: mais(sem.ate, -7) };
  const iva = ivaDaEmpresa(app, empresaId);
  const itens = [];
  const sec = (titulo, linhas) => {
    if (linhas && linhas.length) itens.push({ titulo: titulo, linhas: linhas });
  };
  const seguro = (fn) => {
    try {
      return fn();
    } catch (err) {
      console.log('[resumo semanal] ' + err);
      return null;
    }
  };
  const fichaCusto = custosDasFichas(app, empresaId);
  sec('Vendas', seguro(() => linhasVendas(app, empresaId, sem, ant, iva, fichaCusto)));
  sec('Desperdício', seguro(() => linhasDesperdicio(app, empresaId, sem, fichaCusto)));
  sec('Equipa', seguro(() => linhasHoras(app, empresaId, sem)));
  sec('Preços que subiram (7 dias)', seguro(() => linhasPrecos(app, empresaId, agora)));
  sec('Na próxima semana', seguro(() => linhasProximaSemana(app, empresaId, agora)));
  sec(
    'Formações a caducar',
    seguro(() => require(__hooks + '/avisos.js').formacoesACaducar(app, empresaId)),
  );

  let nome = '';
  try {
    nome = app.findRecordById('empresas', empresaId).getString('nome');
  } catch (_) {}
  const d = (x) => dois(x.getDate()) + '/' + dois(x.getMonth() + 1);
  const cab = 'Resumo da semana ' + d(sem.de) + '–' + d(sem.ate) + (nome ? ' — ' + nome : '');
  let texto = cab + '\n';
  let html = '<h3>' + escHtml(cab) + '</h3>';
  if (!itens.length) {
    texto += '\nSem dados desta semana para resumir.';
    html += '<p>Sem dados desta semana para resumir.</p>';
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
  return { vazio: !itens.length, texto: texto.trim(), html: html, itens: itens, fechado: false, assunto: '[gc_turnkey] ' + cab };
}

module.exports = { montar, ultimaSemana };
