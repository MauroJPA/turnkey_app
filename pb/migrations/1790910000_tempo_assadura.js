/// <reference path="../pb_data/types.d.ts" />

// Tempo de assadura (em minutos) de cada produto — fica na ficha técnica e
// aparece na montagem (mise en place / produzir) e no forno da contagem diária.

migrate(
  (app) => {
    const fichas = app.findCollectionByNameOrId('fichas_tecnicas');
    if (!fichas.fields.getByName('tempo_assadura_min')) {
      fichas.fields.add(
        new Field({
          type: 'number',
          name: 'tempo_assadura_min',
          required: false,
          min: 0,
          max: 600,
        }),
      );
      app.save(fichas);
    }
  },
  (app) => {
    const fichas = app.findCollectionByNameOrId('fichas_tecnicas');
    if (fichas.fields.getByName('tempo_assadura_min')) {
      fichas.fields.removeByName('tempo_assadura_min');
      app.save(fichas);
    }
  },
);
