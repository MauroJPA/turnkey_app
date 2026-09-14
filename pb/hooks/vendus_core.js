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
// Só documentos de venda reais (FT/FS/FR/FG) e não cancelados (status=N) —
// orçamentos, guias e notas de crédito ficam de fora por agora.

var TIPOS_VENDA = 'FT,FS,FR,FG';

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

function buscarDocumentos(apiKey, opts) {
  var since = (opts && opts.since) || '';
  var until = (opts && opts.until) || '';
  var page = 1;
  var perPage = 100;
  var todos = [];

  for (;;) {
    // Autenticação por parâmetro (em vez de cabeçalho Bearer/Basic) — é o
    // método mais simples e sem ambiguidade de formato; os três métodos são
    // equivalentes segundo a documentação do Vendus.
    var url =
      'https://www.vendus.pt/ws/v1.1/documents/?api_key=' +
      encodeURIComponent(apiKey) +
      '&type=' +
      TIPOS_VENDA +
      '&status=N&per_page=' +
      perPage +
      '&page=' +
      page;
    if (since) url += '&since=' + encodeURIComponent(since);
    if (until) url += '&until=' + encodeURIComponent(until);

    var resp;
    try {
      resp = $http.send({ url: url, method: 'GET', timeout: 60 });
    } catch (err) {
      throw new Error('Falha de rede ao contactar o Vendus: ' + err);
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
    todos = todos.concat(lote);
    if (lote.length < perPage || page > 50) break;
    page++;
  }
  return todos;
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
  var until = (opts && opts.ate) || '';

  var docs;
  try {
    docs = buscarDocumentos(apiKey, { since: since, until: until });
  } catch (err) {
    return { ok: false, code: 502, message: String(err) };
  }

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

  var vendasCriadas = 0;
  var duplicadasIgnoradas = 0;
  var itensCriados = 0;
  var itensSemFicha = 0;
  var maisRecente = since;

  for (var i = 0; i < docs.length; i++) {
    var doc = docs[i];
    var vendusId = String(doc.id != null ? doc.id : '');
    if (!vendusId) continue;
    var dataDoc = String(doc.date || doc.local_time || '').substring(0, 10);
    if (dataDoc && (!maisRecente || dataDoc > maisRecente)) maisRecente = dataDoc;

    var existentes = app.findRecordsByFilter(
      'vendas',
      'empresa = {:e} && vendus_id = {:v}',
      '',
      1,
      0,
      { e: empresaId, v: vendusId },
    );
    if (existentes.length > 0) {
      duplicadasIgnoradas++;
      continue;
    }

    var itens = Array.isArray(doc.items) ? doc.items : [];
    if (!itens.length) continue;

    try {
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

          itensCriados++;
          if (!match) itensSemFicha++;
        }
      });
      vendasCriadas++;
    } catch (err) {
      console.log('[vendus] falha ao importar documento ' + vendusId + ': ' + err);
    }
  }

  if (maisRecente && maisRecente !== since) {
    empresa.set('vendus_ultima_sincronizacao', maisRecente);
    app.save(empresa);
  }

  return {
    ok: true,
    vendasCriadas: vendasCriadas,
    duplicadasIgnoradas: duplicadasIgnoradas,
    itensCriados: itensCriados,
    itensSemFicha: itensSemFicha,
  };
}

module.exports = {
  sincronizarEmpresa: sincronizarEmpresa,
  melhorMatchFicha: melhorMatchFicha,
  scoreMatchFicha: scoreMatchFicha,
  buscarDocumentos: buscarDocumentos,
};
