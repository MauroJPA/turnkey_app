/// <reference path="../pb_data/types.d.ts" />

// Ingrediente genérico ↔ produtos de compra (ver a migration
// 1707955205_ingrediente_produtos.js).
//
//   recalcularGenerico(app, ingredienteId)
//     O custo do genérico (preco, gramas_embalagem, preco_atualizado_em) E a
//     marca/fornecedor mostrados na lista de ingredientes passam a ser os do
//     produto com a COMPRA MAIS RECENTE (data do preço; em caso de empate, o
//     último a ser gravado) — há sempre vários produtos/fornecedores por
//     ingrediente (ver "Produtos de compra"); este é só o que manda no custo
//     e no que aparece resumido na lista. Só grava se algo mudou (a gravação
//     dispara a cascata de custos das receitas). Sem produtos válidos, não mexe.
//
//   normalizarDescricao(texto)
//     minúsculas, sem acentos, espaços simples: para comparar descrições de fatura.

function recalcularGenerico(app, ingredienteId) {
  if (!ingredienteId) return;
  var ing;
  try {
    ing = app.findRecordById('ingredientes', ingredienteId);
  } catch (_) {
    return;
  }
  var prods = app.findRecordsByFilter(
    'ingrediente_produtos',
    'ingrediente = {:i}',
    '',
    0,
    0,
    { i: ingredienteId },
  );
  var melhor = null;
  var chave = '';
  for (var i = 0; i < prods.length; i++) {
    var p = prods[i];
    if (!(p.getFloat('preco') > 0 && p.getFloat('embalagem_g') > 0)) continue;
    var k = String(p.getString('preco_atualizado_em') || '').substring(0, 10) + '|' + p.getString('updated');
    if (!melhor || k > chave) {
      melhor = p;
      chave = k;
    }
  }
  if (!melhor) return;
  var preco = melhor.getFloat('preco');
  var emb = melhor.getFloat('embalagem_g');
  var data = melhor.getString('preco_atualizado_em');
  var marca = melhor.getString('marca');
  var fornecedor = melhor.getString('fornecedor');
  var mudou =
    Math.abs(ing.getFloat('preco') - preco) > 1e-9 ||
    Math.abs(ing.getFloat('gramas_embalagem') - emb) > 1e-9 ||
    String(ing.getString('preco_atualizado_em')).substring(0, 10) !== String(data).substring(0, 10) ||
    (marca && ing.getString('marca') !== marca) ||
    (fornecedor && ing.getString('fornecedor') !== fornecedor);
  if (!mudou) return;
  ing.set('preco', preco);
  ing.set('gramas_embalagem', emb);
  if (data) ing.set('preco_atualizado_em', data);
  // só substitui marca/fornecedor do genérico quando o produto mais recente
  // TEM esse dado — nunca apaga o que já lá estava por o produto vir em branco.
  if (marca) ing.set('marca', marca);
  if (fornecedor) ing.set('fornecedor', fornecedor);
  app.save(ing);
}

// Receitas que fixam um produto usam o custo DELE (mesmo que o do genérico não
// mude): quando o produto muda, refaz as receitas desse ingrediente.
// `sempre` = true força (ex.: ao apagar, quando já não dá para saber quem o fixava).
function refazerReceitasFixadas(app, ingredienteId, produtoId, sempre) {
  if (!ingredienteId) return;
  if (!sempre) {
    var fixadas = app.findRecordsByFilter('itens_receita', 'produto = {:p}', '', 1, 0, { p: produtoId });
    if (!fixadas.length) return;
  }
  require(__hooks + '/cascade.js').runCascade(app, 'ingrediente', ingredienteId);
}

function normalizarDescricao(texto) {
  var de = 'áàãâäéèêëíìîïóòõôöúùûüçñ';
  var para = 'aaaaaeeeeiiiiooooouuuucn';
  var s = String(texto || '').toLowerCase().trim();
  var out = '';
  for (var i = 0; i < s.length; i++) {
    var j = de.indexOf(s[i]);
    out += j >= 0 ? para[j] : s[i];
  }
  return out.replace(/\s+/g, ' ');
}

module.exports = { recalcularGenerico, refazerReceitasFixadas, normalizarDescricao };
