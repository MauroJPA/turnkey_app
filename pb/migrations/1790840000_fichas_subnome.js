/// <reference path="../pb_data/types.d.ts" />

// `fichas_tecnicas.subnome`: segundo nome do produto (ex.: "Red Velvet" em
// "Carolina do Sul"), opcional; aparece na página do produto e, se ligado ao
// imprimir, na etiqueta por baixo do nome.
migrate(
  (app) => {
    const fichas = app.findCollectionByNameOrId('fichas_tecnicas');
    if (!fichas.fields.getByName('subnome')) {
      fichas.fields.add(
        new Field({ type: 'text', name: 'subnome', required: false, max: 60 }),
      );
      app.save(fichas);
    }
  },
  (app) => {
    const fichas = app.findCollectionByNameOrId('fichas_tecnicas');
    if (fichas.fields.getByName('subnome')) {
      fichas.fields.removeByName('subnome');
      app.save(fichas);
    }
  },
);
