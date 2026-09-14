/// <reference path="../pb_data/types.d.ts" />

// Núcleo da sincronização com o Vendus (POS/faturação da Gookie) — partilhado
// pelo endpoint POST /api/turnkey/vendus/sincronizar e pelo cron horário.
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

// Busca UMA página. Nunca deixar a chave/URL chegar à mensagem de erro — o
// erro de rede do Go inclui o URL completo pedido (`Get "...&api_key=...":
// ...`), e essa mensagem acaba por chegar à interface da app.
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

  var resp;
  try {
    resp = $http.send({ url: url, method: 'GET', timeout: 45 });
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

  var lote = resp.json;
  if (!Array.isArray(lote)) lote = [];
  return lote;
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

// Cria a `venda`+`vendas_itens` de um documento. Devolve quantos itens
// ficaram sem ficha, para o resumo final.
function importarDocumento(app, empresaId, doc, fichas) {
  var vendusId = String(doc.id != null ? doc.id : '');
  var dataDoc = String(doc.date || doc.local_time || '').substring(0, 10);
  var itens = Array.isArray(doc.items) ? doc.items : [];
  var semFicha = 0;

  app.runInTransaction(function (tx) {
    var venda = new Record(tx.findCollectionByNameOrId('vendas'));
    venda.set('empresa', empresaId);
    venda.set('data', dataDoc || new Date().toISOString().substring(0, 10));
    venda.set('origem', 'vendus');
    venda.set('total', Number(doc.amount_gross || 0));
    venda.set('numero_documento', String(doc.number || ''));
    venda.set('vendus_id', vendusId);
    tx.save(venda);

    for (var j = 0; j < itens.length; j++) {
      var it = itens[j];
      var titulo = String(it.title || '');
      var qtd = Number(it.qty || 0);
      var amounts = it.amounts || {};
      var precoUnit = Number(amounts.gross_unit || 0);
      var totalLinha = Number(amounts.gross_total || qtd * precoUnit);
      var match = melhorMatchFicha(titulo, fichas, 0.34);
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
      tx.save(item);
    }
  });

  return { dataDoc: dataDoc, itens: itens.length, semFicha: semFicha };
}

// --- sincronização --------------------------------------------------------

function sincronizarEmpresa(app, empresaId, opts) {
  var apiKey = $os.getenv('VENDUS_API_KEY');
  if (!apiKey) {
    return { ok: false, code: 503, message: 'Vendus não configurado (falta VENDUS_API_KEY).' };
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
    return {
      id: f.id,
      nome: f.getString('nome'),
      categoria: f.getString('categoria'),
      custoProduto: f.getFloat('custo_produto'),
    };
  });

  // Pré-carrega os `vendus_id` já importados (uma query, não uma por
  // documento) para a verificação de duplicados ser instantânea.
  var jaImportados = {};
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
  }

  var vendasCriadas = 0;
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
      if (TIPOS_NAO_VENDA[doc.type]) continue;

      var vendusId = String(doc.id != null ? doc.id : '');
      if (!vendusId) continue;

      var dataDoc = String(doc.date || doc.local_time || '').substring(0, 10);
      if (dataDoc && dataDoc > maisRecente) maisRecente = dataDoc;

      if (jaImportados[vendusId]) {
        duplicadasIgnoradas++;
        continue;
      }
      var itens = Array.isArray(doc.items) ? doc.items : [];
      if (!itens.length) continue;

      try {
        var r = importarDocumento(app, empresaId, doc, fichas);
        jaImportados[vendusId] = true;
        vendasCriadas++;
        itensCriados += r.itens;
        itensSemFicha += r.semFicha;
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
    duplicadasIgnoradas: duplicadasIgnoradas,
    itensCriados: itensCriados,
    itensSemFicha: itensSemFicha,
    totalDocumentosRecebidos: totalRecebidos,
    tiposDocumentosVistos: tiposVistos,
  };
}

module.exports = {
  sincronizarEmpresa: sincronizarEmpresa,
  melhorMatchFicha: melhorMatchFicha,
  scoreMatchFicha: scoreMatchFicha,
};
