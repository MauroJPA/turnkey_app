/// <reference path="../pb_data/types.d.ts" />

// Núcleo da sincronização com o Vendus (POS/faturação) — partilhado
// pelo endpoint POST /api/gc_turnkey/vendus/sincronizar e pelo cron horário.
//
//   sincronizarEmpresa(app, empresaId, opts)
//     -> { ok:true, vendasCriadas, duplicadasIgnoradas, itensCriados, itensSemFicha }
//     -> { ok:false, code, message }   (503 sem chave; 502 erro do Vendus)
//
// API do Vendus: https://www.vendus.pt/ws/v1.1/documents.doc (auth por
// parâmetro `api_key` com a API KEY gerada em Apps → API na conta Vendus).
// Documentos não cancelados (status=N) que não sejam orçamentos/guias/
// encomendas/notas de crédito ou débito (ver TIPOS_NAO_VENDA) — o resto
// conta como venda real (FT, FS, FR, FG, VD, ...).
//
// Processa página a página (em vez de ir buscar tudo antes de gravar nada):
// se uma sincronização grande falhar/expirar a meio, o que já foi
// processado fica gravado e `vendus_ultima_sincronizacao` avança até aí —
// a tentativa seguinte continua de onde ficou, em vez de repetir sempre o
// mesmo trabalho e falhar sempre no mesmo sítio.

// A documentação do Vendus diz que `type` aceita uma lista separada por
// vírgulas (`type=FT,FS,FR,FG`), mas na prática a API real devolveu
// `{"code":"A001","message":"Tipo de documento inválido."}` para esse
// formato — por isso filtra-se aqui, depois de receber os documentos, em
// vez de depender do parâmetro `type` do pedido.
//
// Em vez de uma lista fechada de tipos "de venda" (arriscado — faltou "VD",
// Venda a Dinheiro, num teste real; pode haver outros tipos válidos que
// desconhecemos), excluem-se só os tipos claramente NÃO são vendas
// (orçamentos, guias, encomendas, pró-forma, consulta de mesa). Notas de
// crédito/débito (NC/ND) também ficam de fora por agora — precisariam de
// tratamento especial (valor negativo) que ainda não existe aqui.
//
// RG (Recibo) também fica de fora: confirmado com dados reais que uma
// venda paga gera DOIS documentos — a fatura (FT) e o seu recibo (RG),
// com o mesmo valor e data, o RG referenciando a FT em `related_docs`.
// Contar os dois duplicava a receita.
var TIPOS_NAO_VENDA = {
  OT: true, // Orçamento
  EC: true, // Encomenda
  PF: true, // Fatura Pró-Forma
  DC: true, // Consulta de Mesa
  GA: true, // Guia de Ativos Próprios
  GD: true, // Guia de Devolução
  GR: true, // Guia de Remessa
  GT: true, // Guia de Transporte
  NC: true, // Nota de Crédito
  ND: true, // Nota de Débito
  RG: true, // Recibo (já contado através da fatura correspondente)
};

// Mensagem de erro mais útil do que "HTTP 400" — o Vendus normalmente devolve
// um corpo com o motivo (ex.: parâmetro inválido, chave sem permissões).
function mensagemErroVendus(resp) {
  try {
    if (resp.json && typeof resp.json === 'object') {
      if (resp.json.message) return String(resp.json.message);
      if (resp.json.error) {
        return typeof resp.json.error === 'string'
          ? resp.json.error
          : JSON.stringify(resp.json.error);
      }
      return JSON.stringify(resp.json);
    }
  } catch (_) {}
  return String(resp.raw || '').substring(0, 300);
}

// Chamada HTTP partilhada. Nunca deixar a chave/URL chegar à mensagem de
// erro — o erro de rede do Go inclui o URL completo pedido (`Get
// "...&api_key=...": ...`), e essa mensagem acaba por chegar à interface
// da app.
function chamarVendus(url, timeout) {
  var resp;
  try {
    resp = $http.send({ url: url, method: 'GET', timeout: timeout });
  } catch (err) {
    var msg = String(err);
    var motivo =
      msg.indexOf('deadline exceeded') !== -1 || msg.indexOf('timeout') !== -1
        ? 'demorou demasiado tempo a responder'
        : 'falha de rede';
    throw new Error('Não consegui contactar o Vendus (' + motivo + ').');
  }
  if (resp.statusCode < 200 || resp.statusCode >= 300) {
    throw new Error(
      'Vendus respondeu com o erro HTTP ' +
        resp.statusCode +
        ': ' +
        mensagemErroVendus(resp),
    );
  }
  return resp.json;
}

// Busca UMA página da LISTA de documentos — só cabeçalho (id, tipo, data,
// valor total), sem as linhas de produto (ver buscarDetalheDocumento).
function buscarPagina(apiKey, opts) {
  var url =
    'https://www.vendus.pt/ws/v1.1/documents/?api_key=' +
    encodeURIComponent(apiKey) +
    '&status=N&per_page=' +
    opts.perPage +
    '&page=' +
    opts.page;
  if (opts.since) url += '&since=' + encodeURIComponent(opts.since);
  if (opts.until) url += '&until=' + encodeURIComponent(opts.until);

  var lote = chamarVendus(url, 45);
  return Array.isArray(lote) ? lote : [];
}

// Busca UM documento completo (com as linhas de produto em `items`) — a
// lista de documentos (buscarPagina) não as traz, mesmo com
// `view=detailed` (esse parâmetro só acrescenta cliente/pagamento).
function buscarDetalheDocumento(apiKey, id) {
  var url =
    'https://www.vendus.pt/ws/v1.1/documents/' +
    encodeURIComponent(String(id)) +
    '/?api_key=' +
    encodeURIComponent(apiKey);
  var doc = chamarVendus(url, 30);
  return doc && typeof doc === 'object' ? doc : {};
}

// --- emparelhamento por nome (mesma lógica de match_ficha.dart) ---------

function normalizar(s) {
  var acentos = {
    'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a', 'ä': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e',
    'í': 'i', 'ì': 'i',
    'ó': 'o', 'ò': 'o', 'õ': 'o', 'ô': 'o',
    'ú': 'u', 'ù': 'u', 'ü': 'u',
    'ç': 'c',
  };
  var out = String(s).toLowerCase();
  for (var k in acentos) out = out.split(k).join(acentos[k]);
  return out;
}

function tokens(s) {
  var norm = normalizar(s).replace(/[^a-z0-9 ]/g, ' ');
  var parts = norm.split(/\s+/).filter(function (t) {
    return t.length > 2;
  });
  var set = {};
  for (var i = 0; i < parts.length; i++) set[parts[i]] = true;
  return set;
}

function scoreMatchFicha(descricaoVenda, fichaTexto) {
  var a = tokens(descricaoVenda);
  var b = tokens(fichaTexto);
  var aKeys = Object.keys(a);
  var bKeys = Object.keys(b);
  if (!aKeys.length || !bKeys.length) return 0;
  var inter = 0;
  for (var i = 0; i < aKeys.length; i++) if (b[aKeys[i]]) inter++;
  var uni = {};
  for (var i = 0; i < aKeys.length; i++) uni[aKeys[i]] = true;
  for (var i = 0; i < bKeys.length; i++) uni[bKeys[i]] = true;
  return inter / Object.keys(uni).length;
}

function melhorMatchFicha(descricaoVenda, fichas, minScore) {
  minScore = minScore == null ? 0.34 : minScore;
  var melhor = null;
  var melhorScore = 0;
  for (var i = 0; i < fichas.length; i++) {
    var f = fichas[i];
    var texto = (f.nome || '') + ' ' + (f.categoria || '');
    var s = scoreMatchFicha(descricaoVenda, texto);
    if (s > melhorScore) {
      melhorScore = s;
      melhor = f;
    }
  }
  return melhorScore >= minScore ? melhor : null;
}

// Por ordem: 1) descrição já ligada manualmente antes (nomes_venda, ver
// vendas_ligar_produto.js); 2) semelhança de palavras (melhorMatchFicha).
function fichaParaVenda(descricaoVenda, fichas, minScore) {
  var desc = normalizar(descricaoVenda).replace(/\s+/g, ' ').trim();
  for (var i = 0; i < fichas.length; i++) {
    var nomes = fichas[i].nomesVenda || [];
    if (nomes.indexOf(desc) !== -1) return fichas[i];
  }
  return melhorMatchFicha(descricaoVenda, fichas, minScore);
}

// --- dados extra para o Relatório geral ------------------------------------
//
// Hora, método de pagamento e valores sem IVA. São lidos de forma defensiva
// (a API do Vendus pode não os trazer): quando faltam, ficam em branco e o
// relatório avisa que não há dados.

// Canal atribuído às vendas que vêm do POS Vendus (a loja). Pode ser
// corrigido venda a venda na app (ex.: pedido de uma plataforma de entrega
// registado na caixa).
var CANAL_VENDUS = 'Loja física';

function extrasDocumento(doc, detalhe) {
  var d = doc || {};
  var det = detalhe || {};
  var lt = String(det.local_time || d.local_time || det.system_time || d.system_time || '');
  var hora = lt.length >= 16 ? lt.substring(11, 16) : '';
  if (!/^\d{2}:\d{2}$/.test(hora)) hora = '';

  var metodo = '';
  var pagamentos = det.payments || d.payments;
  if (Array.isArray(pagamentos) && pagamentos.length) {
    var nomes = [];
    for (var i = 0; i < pagamentos.length; i++) {
      var pg = pagamentos[i] || {};
      var nome = String(pg.title || pg.label || pg.name || pg.mode || pg.type || '').trim();
      if (nome && nomes.indexOf(nome) === -1) nomes.push(nome);
    }
    metodo = nomes.join(' + ').substring(0, 60);
  }
  return { hora: hora, metodoPagamento: metodo };
}

function extrasItem(it) {
  var a = (it && it.amounts) || {};
  var bruto = Number(a.gross_total);
  var liquido = Number(a.net_total);
  var out = { valorSemIva: null, ivaPercent: null, desconto: null };
  if (isFinite(liquido) && a.net_total !== undefined && a.net_total !== null) {
    out.valorSemIva = Math.round(liquido * 100) / 100;
    if (isFinite(bruto) && liquido > 0 && bruto >= liquido) {
      out.ivaPercent = Math.round((bruto / liquido - 1) * 1000) / 10;
    }
  }
  var desc = Number(it && (it.discount_amount !== undefined ? it.discount_amount : a.discount));
  if (isFinite(desc) && desc > 0) out.desconto = Math.round(desc * 100) / 100;
  return out;
}

// Vendas importadas antes destes campos existirem: se o documento ainda está
// ao alcance do Vendus, preenche hora/pagamento/canal e os valores sem IVA das
// linhas (pela ordem em que foram criadas). Nunca mexe no que já tem valor.
function completarVendaExistente(app, vendaId, doc, detalhe) {
  var extras = extrasDocumento(doc, detalhe);
  var itens = Array.isArray(detalhe && detalhe.items) ? detalhe.items : [];
  app.runInTransaction(function (tx) {
    var venda = tx.findRecordById('vendas', vendaId);
    if (!venda.getString('canal')) venda.set('canal', CANAL_VENDUS);
    if (!venda.getString('hora') && extras.hora) venda.set('hora', extras.hora);
    if (!venda.getString('metodo_pagamento') && extras.metodoPagamento) {
      venda.set('metodo_pagamento', extras.metodoPagamento);
    }
    tx.save(venda);

    var linhas = tx.findRecordsByFilter('vendas_itens', 'venda = {:v}', 'created', 0, 0, {
      v: vendaId,
    });
    if (linhas.length !== itens.length) return; // não dá para emparelhar com segurança
    for (var i = 0; i < linhas.length; i++) {
      var ex = extrasItem(itens[i]);
      var linha = linhas[i];
      var mudou = false;
      if (ex.valorSemIva !== null && !linha.getFloat('valor_sem_iva')) {
        linha.set('valor_sem_iva', ex.valorSemIva);
        mudou = true;
      }
      if (ex.ivaPercent !== null && !linha.getFloat('iva_percent')) {
        linha.set('iva_percent', ex.ivaPercent);
        mudou = true;
      }
      if (ex.desconto !== null && !linha.getFloat('desconto')) {
        linha.set('desconto', ex.desconto);
        mudou = true;
      }
      if (mudou) tx.save(linha);
    }
  });
}

// Cria a `venda`+`vendas_itens` de um documento (já com os `itens`
// completos, vindos de buscarDetalheDocumento). Devolve quantos itens
// ficaram sem ficha, para o resumo final.
function importarDocumento(app, empresaId, doc, itens, fichas, detalhe) {
  var vendusId = String(doc.id != null ? doc.id : '');
  var dataDoc = String(doc.date || doc.local_time || '').substring(0, 10);
  var semFicha = 0;

  app.runInTransaction(function (tx) {
    var venda = new Record(tx.findCollectionByNameOrId('vendas'));
    venda.set('empresa', empresaId);
    venda.set('data', dataDoc || new Date().toISOString().substring(0, 10));
    venda.set('origem', 'vendus');
    venda.set('total', Number(doc.amount_gross || 0));
    venda.set('numero_documento', String(doc.number || ''));
    venda.set('vendus_id', vendusId);
    var extrasDoc = extrasDocumento(doc, detalhe);
    venda.set('canal', CANAL_VENDUS);
    if (extrasDoc.hora) venda.set('hora', extrasDoc.hora);
    if (extrasDoc.metodoPagamento) venda.set('metodo_pagamento', extrasDoc.metodoPagamento);
    tx.save(venda);

    for (var j = 0; j < itens.length; j++) {
      var it = itens[j];
      var titulo = String(it.title || '');
      var qtd = Number(it.qty || 0);
      var amounts = it.amounts || {};
      var precoUnit = Number(amounts.gross_unit || 0);
      var totalLinha = Number(amounts.gross_total || qtd * precoUnit);
      var match = fichaParaVenda(titulo, fichas, 0.34);
      if (!match) semFicha++;

      var item = new Record(tx.findCollectionByNameOrId('vendas_itens'));
      item.set('empresa', empresaId);
      item.set('venda', venda.id);
      if (match) item.set('ficha', match.id);
      item.set('descricao', titulo);
      item.set('quantidade', qtd);
      item.set('preco_unitario', precoUnit);
      item.set('total_linha', totalLinha);
      item.set('custo_unitario_snapshot', match ? match.custoProduto : 0);
      var exItem = extrasItem(it);
      if (exItem.valorSemIva !== null) item.set('valor_sem_iva', exItem.valorSemIva);
      if (exItem.ivaPercent !== null) item.set('iva_percent', exItem.ivaPercent);
      if (exItem.desconto !== null) item.set('desconto', exItem.desconto);
      tx.save(item);
    }
  });

  return { dataDoc: dataDoc, itens: itens.length, semFicha: semFicha };
}

// --- sincronização --------------------------------------------------------

// Guarda quando se tentou sincronizar e como correu (a app mostra "vendas
// atualizadas às 14:05" e avisa se deixar de sincronizar). Não guarda nada
// se o Vendus nem está configurado.
function registarEstado(app, empresaId, r) {
  try {
    if (!r || r.code === 503 || r.code === 404) return;
    var empresa = app.findRecordById('empresas', empresaId);
    var agora = new Date().toISOString();
    empresa.set('vendus_tentativa_em', agora);
    if (r.ok) {
      empresa.set('vendus_ok_em', agora);
      empresa.set(
        'vendus_resultado',
        r.vendasCriadas > 0 ? r.vendasCriadas + ' venda(s) nova(s)' : 'Tudo em dia',
      );
    } else {
      empresa.set(
        'vendus_resultado',
        String(r.message || 'Falhou').replace(/api_key=[^&\s]+/g, 'api_key=***').substring(0, 280),
      );
    }
    app.save(empresa);
  } catch (_) {}
}

function sincronizarEmpresa(app, empresaId, opts) {
  var r = sincronizarEmpresaBase(app, empresaId, opts);
  registarEstado(app, empresaId, r);
  return r;
}

function sincronizarEmpresaBase(app, empresaId, opts) {
  // Token da própria empresa (cifrado na base de dados). A variável de
  // ambiente VENDUS_API_KEY é só um recurso para a empresa indicada em
  // VENDUS_SYNC_EMPRESA (uma só empresa, antes de guardar o token na app): nunca
  // serve a outras empresas.
  var apiKey = null;
  try {
    apiKey = require(`${__hooks}/segredos.js`).ler(app, empresaId, 'vendus');
  } catch (_) {}
  if (!apiKey && $os.getenv('VENDUS_SYNC_EMPRESA') === empresaId) {
    apiKey = $os.getenv('VENDUS_API_KEY');
  }
  if (!apiKey) {
    return {
      ok: false,
      code: 503,
      message: 'Vendus não configurado: indica o token em Configurações → Integrações.',
    };
  }

  var empresa;
  try {
    empresa = app.findRecordById('empresas', empresaId);
  } catch (_) {
    return { ok: false, code: 404, message: 'Empresa não encontrada.' };
  }

  var since = (opts && opts.desde) || empresa.getString('vendus_ultima_sincronizacao') || '';
  since = since ? String(since).substring(0, 10) : '';
  if (!since) {
    // Primeira sincronização desta empresa: não pedir a história completa
    // da conta Vendus (podem ser milhares de documentos, muito lento) — só
    // os últimos 90 dias. Vendas mais antigas continuam disponíveis por
    // registo manual/CSV.
    var noventaDiasAtras = new Date();
    noventaDiasAtras.setDate(noventaDiasAtras.getDate() - 90);
    since = noventaDiasAtras.toISOString().substring(0, 10);
  }
  var until = (opts && opts.ate) || '';

  var fichasRecs = app.findRecordsByFilter(
    'fichas_tecnicas',
    "empresa = {:e} && deletado = false",
    '',
    0,
    0,
    { e: empresaId },
  );
  var fichas = fichasRecs.map(function (f) {
    var nomesVenda = [];
    try {
      var v = JSON.parse(f.getString('nomes_venda') || '[]');
      if (Array.isArray(v)) nomesVenda = v;
    } catch (_) {}
    return {
      id: f.id,
      nome: f.getString('nome'),
      categoria: f.getString('categoria'),
      custoProduto: f.getFloat('custo_produto'),
      nomesVenda: nomesVenda,
    };
  });

  // Pré-carrega os `vendus_id` já importados (uma query, não uma por
  // documento) para a verificação de duplicados ser instantânea.
  var jaImportados = {};
  var porCompletar = {}; // vendus_id -> id da venda (importada antes dos campos do relatório)
  var existentesRecs = app.findRecordsByFilter(
    'vendas',
    "empresa = {:e} && vendus_id != ''",
    '',
    0,
    0,
    { e: empresaId },
  );
  for (var k = 0; k < existentesRecs.length; k++) {
    jaImportados[existentesRecs[k].getString('vendus_id')] = true;
    if (!existentesRecs[k].getString('canal') && !existentesRecs[k].getString('hora')) {
      porCompletar[existentesRecs[k].getString('vendus_id')] = existentesRecs[k].id;
    }
  }

  var vendasCriadas = 0;
  var vendasCompletadas = 0;
  var duplicadasIgnoradas = 0;
  var itensCriados = 0;
  var itensSemFicha = 0;
  var totalRecebidos = 0;
  var tiposVistos = {};
  var maisRecente = since;
  var perPage = 100;
  var page = 1;

  var guardarProgresso = function () {
    if (maisRecente && maisRecente !== since) {
      empresa.set('vendus_ultima_sincronizacao', maisRecente);
      app.save(empresa);
    }
  };

  for (;;) {
    var pagina;
    try {
      pagina = buscarPagina(apiKey, {
        since: since,
        until: until,
        page: page,
        perPage: perPage,
      });
    } catch (err) {
      guardarProgresso();
      return {
        ok: false,
        code: 502,
        message:
          String(err) +
          (vendasCriadas > 0
            ? ' (' + vendasCriadas + ' venda(s) já importada(s) antes deste erro — a próxima sincronização continua a partir daí.)'
            : ''),
        totalDocumentosRecebidos: totalRecebidos,
        tiposDocumentosVistos: tiposVistos,
      };
    }

    for (var i = 0; i < pagina.length; i++) {
      var doc = pagina[i];
      totalRecebidos++;
      var tipoChave = doc.type || '(sem tipo)';
      tiposVistos[tipoChave] = (tiposVistos[tipoChave] || 0) + 1;
      var dataDoc = String(doc.date || doc.local_time || '').substring(0, 10);

      // Tipos que não são vendas (orçamentos, guias, recibos...) — não há
      // nada a tentar de novo, avança a marca de progresso e segue.
      if (TIPOS_NAO_VENDA[doc.type]) {
        if (dataDoc && dataDoc > maisRecente) maisRecente = dataDoc;
        continue;
      }

      var vendusId = String(doc.id != null ? doc.id : '');
      if (!vendusId) continue;

      if (jaImportados[vendusId]) {
        duplicadasIgnoradas++;
        if (porCompletar[vendusId]) {
          try {
            completarVendaExistente(
              app,
              porCompletar[vendusId],
              doc,
              buscarDetalheDocumento(apiKey, vendusId),
            );
            vendasCompletadas++;
          } catch (err) {
            console.log('[vendus] não consegui completar a venda ' + vendusId + ': ' + err);
          }
          delete porCompletar[vendusId];
        }
        if (dataDoc && dataDoc > maisRecente) maisRecente = dataDoc;
        continue;
      }

      // A lista só dá o cabeçalho — as linhas de produto vêm só ao pedir o
      // documento individual. Falha aqui NÃO avança `maisRecente`, para
      // este documento ser tentado outra vez na próxima sincronização.
      var detalhe;
      try {
        detalhe = buscarDetalheDocumento(apiKey, vendusId);
      } catch (err) {
        console.log(
          '[vendus] falha ao buscar detalhe do documento ' + vendusId + ': ' + err,
        );
        continue;
      }
      var itens = Array.isArray(detalhe.items) ? detalhe.items : [];
      if (!itens.length) {
        if (dataDoc && dataDoc > maisRecente) maisRecente = dataDoc;
        continue;
      }

      try {
        var r = importarDocumento(app, empresaId, doc, itens, fichas, detalhe);
        jaImportados[vendusId] = true;
        vendasCriadas++;
        itensCriados += r.itens;
        itensSemFicha += r.semFicha;
        if (dataDoc && dataDoc > maisRecente) maisRecente = dataDoc;
      } catch (err) {
        console.log('[vendus] falha ao importar documento ' + vendusId + ': ' + err);
      }
    }

    if (pagina.length < perPage || page > 50) break;
    page++;
  }

  guardarProgresso();

  return {
    ok: true,
    vendasCriadas: vendasCriadas,
    vendasCompletadas: vendasCompletadas,
    duplicadasIgnoradas: duplicadasIgnoradas,
    itensCriados: itensCriados,
    itensSemFicha: itensSemFicha,
    totalDocumentosRecebidos: totalRecebidos,
    tiposDocumentosVistos: tiposVistos,
  };
}

module.exports = {
  extrasDocumento: extrasDocumento,
  extrasItem: extrasItem,
  sincronizarEmpresa: sincronizarEmpresa,
  melhorMatchFicha: melhorMatchFicha,
  scoreMatchFicha: scoreMatchFicha,
};
