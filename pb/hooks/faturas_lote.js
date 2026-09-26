/// <reference path="../pb_data/types.d.ts" />

// Análise de ficheiros GRANDES (ex.: um PDF de 90 páginas digitalizado no telemóvel,
// com faturas de vários fornecedores). Em vez de mandar tudo à IA de uma vez (o
// limite da Google é ~20 MB por pedido), o servidor lê o ficheiro já guardado e
// analisa-o em JANELAS de páginas, uma por pedido, para a app poder mostrar o
// progresso e retomar se algo falhar:
//
//   prepararLote(app, fatura)          conta as páginas e guarda o estado (em dados_ia.lote)
//   analisarProximaParte(app, fatura)  corta a próxima janela (qpdf), lê-a com a IA e guarda
//   concluirLote(app, fatura)          junta os documentos (também os que atravessam
//                                      janelas), separa em faturas e aplica (aplicarLista)
//
// Variáveis: GC_TURNKEY_JANELA_PAGINAS (por omissão 6 páginas por pedido).

var LIMITE_BASE64 = 14000000; // ~14 MB de base64 por pedido (a Google aceita ~20 MB)

function caminhoFicheiro(app, fatura) {
  var nome = fatura.getString('ficheiro');
  return nome ? String(app.dataDir()) + '/storage/' + fatura.baseFilesPath() + '/' + nome : '';
}

function lerLote(fatura) {
  try {
    var d = JSON.parse(fatura.getString('dados_ia') || '{}');
    return d && d.lote ? d.lote : null;
  } catch (_) {
    return null;
  }
}

function guardarLote(app, fatura, lote) {
  fatura.set('dados_ia', { lote: lote });
  app.save(fatura);
}

function base64De(caminho) {
  return toString($os.cmd('base64', '-w0', caminho).output()).trim();
}

function mimeDe(nome) {
  var n = String(nome || '').toLowerCase();
  if (/\.pdf$/.test(n)) return 'application/pdf';
  if (/\.png$/.test(n)) return 'image/png';
  if (/\.webp$/.test(n)) return 'image/webp';
  return 'image/jpeg';
}

function prepararLote(app, fatura) {
  var nome = fatura.getString('ficheiro');
  var origem = caminhoFicheiro(app, fatura);
  if (!origem) return { ok: false, code: 400, message: 'Esta fatura não tem ficheiro.' };
  var ehPdf = /\.pdf$/i.test(nome);
  var paginas = 1;
  if (ehPdf) {
    try {
      paginas = parseInt(toString($os.cmd('qpdf', '--show-npages', origem).output()).trim(), 10);
    } catch (err) {
      console.log('[faturas] qpdf: ' + String(err).substring(0, 160));
      paginas = 0;
    }
    if (!(paginas >= 1)) return { ok: false, code: 500, message: 'Não foi possível ler as páginas do PDF.' };
  }
  var janela = parseInt($os.getenv('GC_TURNKEY_JANELA_PAGINAS') || '6', 10);
  if (!(janela >= 1)) janela = 6;

  // retoma o trabalho já feito (mesmo ficheiro), se houver
  var antigo = lerLote(fatura);
  var retomado = false;
  var lote;
  if (antigo && antigo.paginas === paginas && antigo.ehPdf === ehPdf && antigo.proxima >= 1) {
    lote = antigo;
    retomado = true;
  } else {
    lote = { paginas: paginas, proxima: 1, janela: janela, ehPdf: ehPdf, partes: [] };
  }
  if (fatura.getString('estado') === 'erro') fatura.set('estado', 'nova');
  guardarLote(app, fatura, lote);
  return { ok: true, paginas: paginas, proxima: lote.proxima, janela: lote.janela, retomado: retomado };
}

function analisarProximaParte(app, fatura) {
  var lote = lerLote(fatura);
  if (!lote) return { ok: false, code: 409, message: 'O ficheiro ainda não foi preparado.' };
  if (lote.proxima > lote.paginas) {
    return { ok: true, feito: true, proxima: lote.proxima, paginas: lote.paginas };
  }
  var nome = fatura.getString('ficheiro');
  var origem = caminhoFicheiro(app, fatura);
  if (!origem) return { ok: false, code: 400, message: 'Esta fatura não tem ficheiro.' };

  var inicio = lote.proxima;
  var fim = Math.min(inicio + lote.janela - 1, lote.paginas);
  var b64 = '';
  var tmp = '';
  try {
    if (lote.ehPdf) {
      tmp = String(app.dataDir()) + '/.lote_' + $security.randomString(10);
      $os.mkdirAll(tmp, 0o755);
      var saida = tmp + '/janela.pdf';
      $os.cmd('qpdf', '--empty', '--pages', origem, inicio + '-' + fim, '--', saida).output();
      b64 = base64De(saida);
    } else {
      b64 = base64De(origem);
    }
  } catch (err) {
    console.log('[faturas] janela: ' + String(err).substring(0, 160));
    return { ok: false, code: 500, message: 'Não foi possível preparar as páginas ' + inicio + '-' + fim + '.' };
  } finally {
    if (tmp) {
      try {
        $os.removeAll(tmp);
      } catch (_) {}
    }
  }

  // janela demasiado pesada para a IA: reduz e a app volta a pedir
  if (b64.length > LIMITE_BASE64 && fim > inicio) {
    lote.janela = Math.max(1, Math.floor((fim - inicio + 1) / 2));
    guardarLote(app, fatura, lote);
    return { ok: true, feito: false, reduzido: true, proxima: lote.proxima, paginas: lote.paginas };
  }

  var isLista = (fatura.getString('tipo') || 'fatura') === 'lista_precos';
  var ai = require(__hooks + '/ai.js');
  var r = ai.analisarImagemIA({
    imagemBase64: b64,
    mime: lote.ehPdf ? 'application/pdf' : mimeDe(nome),
    tarefa: 'fatura',
    isLista: isLista,
  });
  if (!r.ok) {
    // não marca a fatura como erro: o lote fica como está e a app pode tentar de novo
    return { ok: false, code: r.code === 503 ? 503 : 502, message: r.message };
  }

  var lista = r.lista && r.lista.length ? r.lista : [r.dados];
  var total = fim - inicio + 1;
  var docs = [];
  for (var i = 0; i < lista.length; i++) {
    var d = lista[i] || {};
    var pags = [];
    var brutas = Array.isArray(d.paginas) ? d.paginas : [];
    for (var k = 0; k < brutas.length; k++) {
      var p = parseInt(brutas[k], 10);
      if (p >= 1 && p <= total && pags.indexOf(p) === -1) pags.push(p + inicio - 1);
    }
    if (!pags.length) {
      // a IA não indicou as páginas: assume a janela toda (se só há um documento)
      if (lista.length === 1) for (var q = inicio; q <= fim; q++) pags.push(q);
    }
    d.paginas = pags.sort(function (x, y) {
      return x - y;
    });
    docs.push(d);
  }
  lote.partes.push({ de: inicio, ate: fim, docs: docs });
  lote.proxima = fim + 1;
  lote.provider = r.provider;
  guardarLote(app, fatura, lote);
  var nDocs = 0;
  for (var j = 0; j < lote.partes.length; j++) nDocs += lote.partes[j].docs.length;
  return { ok: true, feito: lote.proxima > lote.paginas, proxima: lote.proxima, paginas: lote.paginas, documentos: nDocs };
}

function norm(x) {
  return String(x || '').toLowerCase().replace(/\s+/g, '').replace(/[^a-z0-9]/g, '');
}

// O documento `b` (começo de uma janela) é a continuação do `a` (fim da janela anterior)?
function eContinuacao(a, b) {
  var fa = norm(a.fornecedor);
  var fb = norm(b.fornecedor);
  var na = norm(a.numero);
  var nb = norm(b.numero);
  if (!fb && !nb) return true; // página de continuação sem cabeçalho
  if (fa && fb && fa !== fb) return false;
  if (na && nb) return na === nb;
  return !!(fa && fb) || (!na || !nb);
}

function concluirLote(app, fatura) {
  var lote = lerLote(fatura);
  if (!lote) return { ok: false, code: 409, message: 'O ficheiro ainda não foi analisado.' };
  if (lote.proxima <= lote.paginas) {
    return { ok: false, code: 409, message: 'Faltam páginas por analisar (' + (lote.proxima - 1) + ' de ' + lote.paginas + ').' };
  }
  var isLista = (fatura.getString('tipo') || 'fatura') === 'lista_precos';
  var docs = [];
  for (var i = 0; i < lote.partes.length; i++) {
    var parte = lote.partes[i];
    for (var j = 0; j < parte.docs.length; j++) {
      var d = parte.docs[j];
      var ult = docs.length ? docs[docs.length - 1] : null;
      var comecaNaJanela = d.paginas.length && d.paginas[0] === parte.de;
      if (
        ult &&
        j === 0 &&
        comecaNaJanela &&
        ult._fim === parte.de - 1 &&
        (isLista || eContinuacao(ult, d))
      ) {
        // o mesmo documento atravessa duas janelas: junta
        ult.paginas = ult.paginas.concat(d.paginas);
        ult.linhas = (ult.linhas || []).concat(d.linhas || []);
        if (typeof d.total === 'number') ult.total = d.total;
        if (typeof d.iva === 'number') ult.iva = d.iva;
        if (!ult.numero && d.numero) ult.numero = d.numero;
        if (!ult.data && d.data) ult.data = d.data;
        if (!ult.fornecedor && d.fornecedor) ult.fornecedor = d.fornecedor;
        ult._fim = d.paginas[d.paginas.length - 1];
      } else {
        d._fim = d.paginas.length ? d.paginas[d.paginas.length - 1] : parte.ate;
        docs.push(d);
      }
    }
  }
  for (var k = 0; k < docs.length; k++) delete docs[k]._fim;
  if (!docs.length) {
    fatura.set('estado', 'erro');
    fatura.set('dados_ia', { erro: 'A IA não encontrou nenhuma fatura neste ficheiro.' });
    app.save(fatura);
    return { ok: false, code: 502, message: 'A IA não encontrou nenhuma fatura neste ficheiro.' };
  }
  // lista de preços: um só documento com todas as linhas
  if (isLista && docs.length > 1) {
    var todas = [];
    for (var m = 0; m < docs.length; m++) todas = todas.concat(docs[m].linhas || []);
    docs = [{ fornecedor: docs[0].fornecedor, data: docs[0].data, linhas: todas }];
  }
  return require(__hooks + '/faturas_core.js').aplicarLista(app, fatura, docs, lote.provider || '');
}

// Carrega a fatura do pedido e valida sessão/empresa/papel.
function carregar(e) {
  var auth = e.auth;
  var isSuper = auth && auth.collection() && auth.collection().name === '_superusers';
  var id = e.request.pathValue('id');
  var fatura;
  try {
    fatura = e.app.findRecordById('faturas', id);
  } catch (_) {
    throw new NotFoundError('Fatura não encontrada.');
  }
  if (!isSuper) {
    if (!auth || auth.collection().name !== 'users') throw new ForbiddenError('Autenticação necessária.');
    if (auth.getString('empresa') !== fatura.getString('empresa')) throw new ForbiddenError('Fatura de outra empresa.');
    if (auth.getString('papel') === 'viewer') throw new ForbiddenError('Sem permissão.');
  }
  return fatura;
}

module.exports = { prepararLote, analisarProximaParte, concluirLote, carregar };
