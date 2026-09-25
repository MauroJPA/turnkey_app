/// <reference path="../pb_data/types.d.ts" />

// Juntar dois ingredientes: o ORIGEM passa a fazer parte do DESTINO.
//
//   - Tudo o que apontava para o origem passa a apontar para o destino: linhas de
//     receitas e de fichas, stock (soma-se ao do destino), movimentos, lista de
//     compras, linhas de faturas e os PRODUTOS DE COMPRA (com os nomes de fatura
//     já aprendidos).
//   - Os alergénios do origem juntam-se aos do destino (nunca se perde um aviso).
//   - O origem vai para a lixeira (deletado = true), recuperável.
//   - Recalcula o custo do destino (compra mais recente) e refaz receitas/fichas.
//
// Os ingredientes de fabrico próprio (com receita-espelho) não se juntam.

function lerLista(rec, campo) {
  var v = rec.get(campo);
  return Array.isArray(v) ? v.map(String) : [];
}

function juntarIngredientes(app, empresaId, origemId, destinoId) {
  if (!origemId || !destinoId || origemId === destinoId) {
    throw new BadRequestError('Escolhe dois ingredientes diferentes.');
  }
  var origem, destino;
  try {
    origem = app.findRecordById('ingredientes', origemId);
    destino = app.findRecordById('ingredientes', destinoId);
  } catch (_) {
    throw new BadRequestError('Ingrediente não encontrado.');
  }
  if (origem.getString('empresa') !== empresaId || destino.getString('empresa') !== empresaId) {
    throw new ForbiddenError('Ingrediente de outra empresa.');
  }
  if (origem.getBool('deletado') || destino.getBool('deletado')) {
    throw new BadRequestError('Um dos ingredientes está na lixeira.');
  }
  if (
    origem.getString('origem') === 'fabrico_proprio' ||
    destino.getString('origem') === 'fabrico_proprio' ||
    origem.getString('receita_espelho') ||
    destino.getString('receita_espelho')
  ) {
    throw new BadRequestError('Os ingredientes de fabrico próprio não se juntam.');
  }

  var ingCol = app.findCollectionByNameOrId('ingredientes');
  var movidos = {};
  var alergeniosNovos = [];
  var stockSomado = 0;

  app.runInTransaction(function (tx) {
    // gravar sem disparar a cascata a cada linha: refaz-se uma só vez no fim
    var semHooks = tx;
    try {
      if (typeof tx.unsafeWithoutHooks === 'function') semHooks = tx.unsafeWithoutHooks();
    } catch (_) {
      semHooks = tx;
    }

    var cols = tx.findAllCollections();
    for (var i = 0; i < cols.length; i++) {
      var c = cols[i];
      if (c.name === 'ingredientes' || c.name.indexOf('_') === 0 || c.type !== 'base') continue;
      for (var j = 0; j < c.fields.length; j++) {
        var f = c.fields[j];
        if (f.type() !== 'relation' || f.collectionId !== ingCol.id) continue;
        var campo = f.getName();
        var recs = tx.findRecordsByFilter(
          c.name,
          campo + ' = {:o} && empresa = {:e}',
          '',
          0,
          0,
          { o: origemId, e: empresaId },
        );
        for (var k = 0; k < recs.length; k++) {
          var r = recs[k];
          if (c.name === 'inventario') {
            // um só stock por ingrediente: soma ao do destino (se já existir)
            var existentes = tx.findRecordsByFilter(
              'inventario',
              'ingrediente = {:d} && empresa = {:e}',
              '',
              1,
              0,
              { d: destinoId, e: empresaId },
            );
            if (existentes.length) {
              var d = existentes[0];
              d.set('quantidade', d.getFloat('quantidade') + r.getFloat('quantidade'));
              if (r.getFloat('minimo') > d.getFloat('minimo')) d.set('minimo', r.getFloat('minimo'));
              semHooks.save(d);
              stockSomado += r.getFloat('quantidade');
              semHooks.delete(r);
              movidos[c.name] = (movidos[c.name] || 0) + 1;
              continue;
            }
          }
          r.set(campo, destinoId);
          semHooks.save(r);
          movidos[c.name] = (movidos[c.name] || 0) + 1;
        }
      }
    }

    // alergénios: junta os do origem aos do destino
    ['alergenios', 'alergenios_tracos'].forEach(function (campo) {
      var atual = lerLista(destino, campo);
      var extra = lerLista(origem, campo).filter(function (a) {
        return atual.indexOf(a) === -1;
      });
      if (extra.length) {
        destino.set(campo, atual.concat(extra));
        alergeniosNovos = alergeniosNovos.concat(extra);
      }
    });
    // se o destino não tem foto/marca/nome de rótulo, aproveita o do origem
    ['marca', 'caracteristica'].forEach(function (campo) {
      if (!destino.getString(campo) && origem.getString(campo)) destino.set(campo, origem.getString(campo));
    });
    semHooks.save(destino);

    origem.set('deletado', true);
    semHooks.save(origem);
  });

  // custo do destino (compra mais recente) e cascata para receitas/fichas
  var produtos = require(__hooks + '/produtos.js');
  produtos.recalcularGenerico(app, destinoId);
  require(__hooks + '/cascade.js').runCascade(app, 'ingrediente', destinoId);

  return {
    movidos: movidos,
    stockSomado: stockSomado,
    alergeniosAdicionados: alergeniosNovos,
    destino: destino.getString('nome'),
    origem: origem.getString('nome'),
  };
}

module.exports = { juntarIngredientes };
