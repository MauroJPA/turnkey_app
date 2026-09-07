/// <reference path="../pb_data/types.d.ts" />

// M4 — Ligações de eventos do motor de cascata de custos.
//
// NOTA: no PocketBase, o corpo de cada handler corre isolado e NÃO enxerga
// funções/constantes de topo deste ficheiro. Por isso cada handler é
// autocontido e a lógica pesada vem de cascade.js via require().

onRecordAfterUpdateSuccess((e) => {
  try {
    const EPS = 0.001;
    const num = (rec, f) => {
      try {
        return rec.getFloat(f);
      } catch (_) {
        return 0;
      }
    };
    const before = e.record.original();
    const mudou =
      Math.abs(num(e.record, 'preco') - num(before, 'preco')) > EPS ||
      Math.abs(
        num(e.record, 'gramas_embalagem') - num(before, 'gramas_embalagem'),
      ) > EPS;
    if (mudou) {
      require(`${__hooks}/cascade.js`).runCascade(
        e.app,
        'ingrediente',
        e.record.id,
      );
    }
  } catch (err) {
    console.log('[cascata] ingrediente: ' + err);
  }
  e.next();
}, 'ingredientes');

function aoMudarLinha(e) {
  try {
    const rid = e.record.getString('receita');
    if (rid) {
      require(`${__hooks}/cascade.js`).runCascade(e.app, 'receita', rid);
    }
  } catch (err) {
    console.log('[cascata] linha: ' + err);
  }
  e.next();
}

onRecordAfterCreateSuccess(aoMudarLinha, 'itens_receita');
onRecordAfterUpdateSuccess(aoMudarLinha, 'itens_receita');
onRecordAfterDeleteSuccess(aoMudarLinha, 'itens_receita');

onRecordAfterUpdateSuccess((e) => {
  try {
    const EPS = 0.001;
    const num = (rec, f) => {
      try {
        return rec.getFloat(f);
      } catch (_) {
        return 0;
      }
    };
    const r = e.record;
    const before = r.original();
    const relevante =
      r.getBool('publicar_como_ingrediente') !==
        before.getBool('publicar_como_ingrediente') ||
      r.getBool('rendimento_manual') !== before.getBool('rendimento_manual') ||
      Math.abs(
        num(r, 'rendimento_esperado') - num(before, 'rendimento_esperado'),
      ) > EPS;
    if (relevante) {
      require(`${__hooks}/cascade.js`).runCascade(e.app, 'receita', r.id);
    }
  } catch (err) {
    console.log('[cascata] receita: ' + err);
  }
  e.next();
}, 'receitas');
