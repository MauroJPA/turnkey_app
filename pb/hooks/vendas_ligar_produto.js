/// <reference path="../pb_data/types.d.ts" />

// Liga manualmente uma descrição de linha de venda (Vendus/CSV, sem produto
// identificado) a uma Ficha Técnica:
//   1) atualiza TODAS as `vendas_itens` passadas desta empresa com essa
//      descrição exata e ainda sem ficha (`ficha = ''`);
//   2) "aprende" a descrição em `fichas_tecnicas.nomes_venda`, para o
//      próximo CSV/sincronização Vendus reconhecer sozinho da próxima vez
//      (ver match_ficha.dart#fichaParaVenda e vendus_core.js).
//
// Mesmo padrão de aprendizagem que `nomes_fatura` já usa para faturas
// (ingredientes_juntar.js / faturas.pb.js).

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
  return out.replace(/\s+/g, ' ').trim();
}

function ligarProduto(app, empresaId, autorId, descricao, fichaId) {
  var desc = String(descricao || '').trim();
  if (!desc) throw new BadRequestError('Falta a descrição da linha de venda.');
  if (!fichaId) throw new BadRequestError('Escolhe um produto.');

  var ficha;
  try {
    ficha = app.findRecordById('fichas_tecnicas', fichaId);
  } catch (_) {
    throw new BadRequestError('Produto não encontrado.');
  }
  if (ficha.getString('empresa') !== empresaId) {
    throw new ForbiddenError('Produto de outra empresa.');
  }
  if (ficha.getBool('deletado')) {
    throw new BadRequestError('Esse produto está na lixeira.');
  }

  var custo = ficha.getFloat('custo_produto');
  var ligadas = 0;

  app.runInTransaction(function (tx) {
    var itens = tx.findRecordsByFilter(
      'vendas_itens',
      "empresa = {:e} && descricao = {:d} && ficha = ''",
      '',
      0,
      0,
      { e: empresaId, d: desc },
    );
    for (var i = 0; i < itens.length; i++) {
      var item = itens[i];
      item.set('ficha', fichaId);
      item.set('custo_unitario_snapshot', custo);
      tx.save(item);
      ligadas++;
    }

    var normalizada = normalizar(desc);
    var nomes = [];
    try {
      var v = JSON.parse(ficha.getString('nomes_venda') || '[]');
      if (Array.isArray(v)) nomes = v;
    } catch (_) {}
    if (normalizada && nomes.indexOf(normalizada) === -1) {
      nomes.push(normalizada);
      while (nomes.length > 50) nomes.shift();
      ficha.set('nomes_venda', nomes);
      tx.save(ficha);
    }

    try {
      var h = new Record(tx.findCollectionByNameOrId('historico'));
      h.set('empresa', empresaId);
      h.set('entidade_tipo', 'venda');
      h.set('entidade_id', fichaId);
      h.set(
        'descricao',
        'Ligado "' + desc + '" a "' + ficha.getString('nome') + '" — ' +
          ligadas + ' linha(s) de venda atualizada(s).',
      );
      if (autorId) h.set('autor', autorId);
      tx.save(h);
    } catch (_) {
      // histórico é best-effort — nunca bloqueia a ligação em si
    }
  });

  return { ligadas: ligadas, ficha: ficha.getString('nome') };
}

module.exports = { ligarProduto, normalizar };
