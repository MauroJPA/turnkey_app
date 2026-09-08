/// <reference path="../pb_data/types.d.ts" />

// Fase 4 — `empresas.tema`: modo de tema da app (claro/escuro/automático),
// por empresa. A cor (`cor_marca`) e o logótipo (`logo`) já existem.

migrate(
  (app) => {
    const c = app.findCollectionByNameOrId('empresas');
    if (!c.fields.getByName('tema')) {
      c.fields.add(
        new Field({
          type: 'select',
          name: 'tema',
          required: false,
          maxSelect: 1,
          values: ['sistema', 'claro', 'escuro'],
        }),
      );
      app.save(c);
    }
  },
  (app) => {
    const c = app.findCollectionByNameOrId('empresas');
    c.fields.removeByName('tema');
    app.save(c);
  },
);
