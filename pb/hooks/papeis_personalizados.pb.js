/// <reference path="../pb_data/types.d.ts" />

// Papéis personalizados (2.21.0): se o proprietário muda o papel BASE de um
// papel personalizado, as pessoas com esse papel passam a ter o novo papel
// base (é o que o servidor lhes deixa fazer). O proprietário nunca muda.
//
// NOTA: cada handler é autocontido (os handlers correm isolados).

onRecordAfterUpdateSuccess((e) => {
  try {
    const base = e.record.getString('base');
    if (base === e.record.original().getString('base')) {
      e.next();
      return;
    }
    const pessoas = e.app.findRecordsByFilter(
      'users',
      "papel_personalizado = {:p} && papel != 'owner'",
      '',
      0,
      0,
      { p: e.record.id },
    );
    for (const u of pessoas) {
      if (u.getString('empresa') !== e.record.getString('empresa')) continue;
      u.set('papel', base);
      e.app.save(u);
    }
  } catch (err) {
    console.log('[papeis] ao mudar o papel base: ' + String(err && err.message ? err.message : 'desconhecido'));
  }
  e.next();
}, 'papeis_personalizados');
