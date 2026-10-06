/// <reference path="../pb_data/types.d.ts" />

// Alertas de validade por lote — 1.99.0.
// `esgotado`: o lote já foi todo usado / vendido / deitado fora: deixa de dar aviso.
migrate(
  (app) => {
    for (const nome of ['lotes_ingrediente', 'lotes_producao']) {
      const c = app.findCollectionByNameOrId(nome);
      if (!c.fields.getByName('esgotado')) {
        c.fields.add(new Field({ type: 'bool', name: 'esgotado', required: false }));
        app.save(c);
      }
    }
  },
  (app) => {
    for (const nome of ['lotes_ingrediente', 'lotes_producao']) {
      const c = app.findCollectionByNameOrId(nome);
      if (c.fields.getByName('esgotado')) {
        c.fields.removeByName('esgotado');
        app.save(c);
      }
    }
  },
);
