/// <reference path="../pb_data/types.d.ts" />

// Fase 3 — `lista_compras.custo_estimado`: preço estimado da compra desta
// linha (quantidade a comprar × preço/grama do ingrediente), snapshot no
// momento em que a lista é gerada.

migrate(
  (app) => {
    const c = app.findCollectionByNameOrId('lista_compras');
    if (!c.fields.getByName('custo_estimado')) {
      c.fields.add(
        new Field({
          type: 'number',
          name: 'custo_estimado',
          required: false,
          min: 0,
        }),
      );
      app.save(c);
    }
  },
  (app) => {
    const c = app.findCollectionByNameOrId('lista_compras');
    c.fields.removeByName('custo_estimado');
    app.save(c);
  },
);
