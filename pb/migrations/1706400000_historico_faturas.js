/// <reference path="../pb_data/types.d.ts" />

// Permite registar faturas apagadas no `historico`
// (entidade_tipo = 'faturas_apagadas', entidade_id = <empresaId>).

migrate(
  (app) => {
    const c = app.findCollectionByNameOrId('historico');
    const f = c.fields.getByName('entidade_tipo');
    if (f && f.values.indexOf('faturas_apagadas') < 0) {
      f.values = f.values.concat(['faturas_apagadas']);
      app.save(c);
    }
  },
  (app) => {
    const c = app.findCollectionByNameOrId('historico');
    const f = c.fields.getByName('entidade_tipo');
    if (f) {
      f.values = f.values.filter((v) => v !== 'faturas_apagadas');
      app.save(c);
    }
  },
);
