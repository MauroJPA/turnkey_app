/// <reference path="../pb_data/types.d.ts" />

// Fase 4 — `lista_compras`: nota e unidade nos itens (para itens manuais que
// não são ingredientes de receita, ex.: sacos de lixo, sabão, uma tesoura).

migrate(
  (app) => {
    const c = app.findCollectionByNameOrId('lista_compras');
    if (!c.fields.getByName('notas')) {
      c.fields.add(
        new Field({ type: 'text', name: 'notas', required: false, max: 500 }),
      );
    }
    if (!c.fields.getByName('unidade')) {
      c.fields.add(
        new Field({ type: 'text', name: 'unidade', required: false, max: 20 }),
      );
    }
    app.save(c);
  },
  (app) => {
    const c = app.findCollectionByNameOrId('lista_compras');
    c.fields.removeByName('notas');
    c.fields.removeByName('unidade');
    app.save(c);
  },
);
