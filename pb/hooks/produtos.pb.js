/// <reference path="../pb_data/types.d.ts" />

// Sempre que um produto de compra muda, o ingrediente genérico refaz o seu
// custo (compra mais recente) — ver produtos.js.
//
// NOTA: cada handler é autocontido (os handlers correm isolados).

onRecordAfterCreateSuccess((e) => {
  try {
    require(`${__hooks}/produtos.js`).recalcularGenerico(e.app, e.record.getString('ingrediente'));
  } catch (err) {
    console.log('[produtos] ' + err);
  }
  e.next();
}, 'ingrediente_produtos');

onRecordAfterUpdateSuccess((e) => {
  try {
    const p = require(`${__hooks}/produtos.js`);
    const antes = e.record.original().getString('ingrediente');
    const agora = e.record.getString('ingrediente');
    p.recalcularGenerico(e.app, agora);
    if (antes && antes !== agora) p.recalcularGenerico(e.app, antes);
    p.refazerReceitasFixadas(e.app, agora, e.record.id, false);
  } catch (err) {
    console.log('[produtos] ' + err);
  }
  e.next();
}, 'ingrediente_produtos');

onRecordAfterDeleteSuccess((e) => {
  try {
    const p = require(`${__hooks}/produtos.js`);
    const ing = e.record.getString('ingrediente');
    p.recalcularGenerico(e.app, ing);
    p.refazerReceitasFixadas(e.app, ing, e.record.id, true);
  } catch (err) {
    console.log('[produtos] ' + err);
  }
  e.next();
}, 'ingrediente_produtos');
