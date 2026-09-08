/// <reference path="../pb_data/types.d.ts" />

// Fase 3 — `lista_compras.embalagem_g`: snapshot da quantidade da embalagem do
// ingrediente, para a lista mostrar "N sacos" a comprar.

migrate(
  (app) => {
    const c = app.findCollectionByNameOrId('lista_compras');
    if (!c.fields.getByName('embalagem_g')) {
      c.fields.add(
        new Field({
          type: 'number',
          name: 'embalagem_g',
          required: false,
          min: 0,
        }),
      );
      app.save(c);
    }
  },
  (app) => {
    const c = app.findCollectionByNameOrId('lista_compras');
    c.fields.removeByName('embalagem_g');
    app.save(c);
  },
);
