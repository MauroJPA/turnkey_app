/// <reference path="../pb_data/types.d.ts" />

// "Mais usados" no inventário: quando um item entra numa lista de compras,
// incrementa `usos` (+ `ultimo_uso`) na linha de inventário correspondente,
// criando-a a zero se ainda não existir. (A contagem por produção é feita no
// aplicarMovimento de cascade.js.)
//
// Handler isolado — sem dependências de topo.

onRecordAfterCreateSuccess((e) => {
  try {
    const r = e.record;
    const empresaId = r.getString('empresa');
    if (!empresaId) {
      e.next();
      return;
    }
    const ingId = r.getString('ingrediente');
    const desc = r.getString('descricao');
    let campo = null;
    let valor = null;
    if (ingId) {
      campo = 'ingrediente';
      valor = ingId;
    } else if (desc) {
      campo = 'descricao';
      valor = desc;
    }
    if (!campo) {
      e.next();
      return;
    }

    const achados = e.app.findRecordsByFilter(
      'inventario',
      'empresa = {:e} && ' + campo + ' = {:i}',
      '',
      1,
      0,
      { e: empresaId, i: valor },
    );
    let row;
    if (achados.length > 0) {
      row = achados[0];
    } else {
      row = new Record(e.app.findCollectionByNameOrId('inventario'));
      row.set('empresa', empresaId);
      row.set(campo, valor);
      row.set('quantidade', 0);
      if (campo === 'descricao') {
        const cat = r.getString('categoria');
        if (cat) row.set('categoria', cat);
      }
    }
    row.set('usos', row.getFloat('usos') + 1);
    row.set('ultimo_uso', new Date().toISOString());
    e.app.save(row);
  } catch (err) {
    console.log('[inventario_uso] ' + err);
  }
  e.next();
}, 'lista_compras');
