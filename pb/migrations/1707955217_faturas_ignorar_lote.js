/// <reference path="../pb_data/types.d.ts" />

// Faturas antigas que ninguém vai validar (preço/stock) — só interessa
// guardar o ficheiro digitalizado. Acrescenta o estado `ignorada` a
// `faturas.estado`, marcado em lote (ver /api/gc_turnkey/faturas/ignorar-lote
// em pb/hooks/faturas.pb.js). Reabrir e aplicar qualquer linha tira do estado
// `ignorada` sozinho (o /aplicar já recalcula o estado a partir do que falta).

migrate(
  (app) => {
    const faturas = app.findCollectionByNameOrId('faturas');
    const f = faturas.fields.getByName('estado');
    if (f && f.values.indexOf('ignorada') < 0) {
      f.values = f.values.concat(['ignorada']);
      app.save(faturas);
    }
  },
  (app) => {
    const faturas = app.findCollectionByNameOrId('faturas');
    const f = faturas.fields.getByName('estado');
    if (f) {
      f.values = f.values.filter((v) => v !== 'ignorada');
      app.save(faturas);
    }
  },
);
