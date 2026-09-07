/// <reference path="../pb_data/types.d.ts" />

// Campo `procedimento` (texto livre com os passos da receita) — existia no
// meu_app_ia e vale a pena preservar na migração de dados.

migrate(
  (app) => {
    const c = app.findCollectionByNameOrId('receitas');
    if (!c.fields.getByName('procedimento')) {
      c.fields.add(
        new Field({ type: 'editor', name: 'procedimento', required: false }),
      );
      app.save(c);
    }
  },
  (app) => {
    const c = app.findCollectionByNameOrId('receitas');
    c.fields.removeByName('procedimento');
    app.save(c);
  },
);
