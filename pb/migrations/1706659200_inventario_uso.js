/// <reference path="../pb_data/types.d.ts" />

// Inventário: marcar favoritos e contar utilizações.
//
// - `favorito` (bool): a pessoa fixa os itens que quer ver primeiro.
// - `usos` (number) + `ultimo_uso` (date): incrementados no servidor sempre
//   que o item é consumido/produzido numa produção OU entra numa lista de
//   compras. Serve para a vista "Mais usados".

migrate(
  (app) => {
    const c = app.findCollectionByNameOrId('inventario');
    if (!c.fields.getByName('favorito')) {
      c.fields.add(new Field({ type: 'bool', name: 'favorito', required: false }));
    }
    if (!c.fields.getByName('usos')) {
      c.fields.add(
        new Field({ type: 'number', name: 'usos', required: false, min: 0 }),
      );
    }
    if (!c.fields.getByName('ultimo_uso')) {
      c.fields.add(
        new Field({ type: 'date', name: 'ultimo_uso', required: false }),
      );
    }
    app.save(c);
  },
  (app) => {
    const c = app.findCollectionByNameOrId('inventario');
    for (const f of ['favorito', 'usos', 'ultimo_uso']) {
      if (c.fields.getByName(f)) c.fields.removeByName(f);
    }
    app.save(c);
  },
);
