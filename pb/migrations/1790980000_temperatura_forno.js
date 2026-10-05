/// <reference path="../pb_data/types.d.ts" />

// Temperatura do forno (°C) de cada produto — fica na ficha técnica e aparece
// ao assar, junto com o tempo de assadura (Contagem, montagem/produzir, agenda).

migrate(
  (app) => {
    const fichas = app.findCollectionByNameOrId('fichas_tecnicas');
    if (!fichas.fields.getByName('temperatura_forno_c')) {
      fichas.fields.add(
        new Field({
          type: 'number',
          name: 'temperatura_forno_c',
          required: false,
          min: 0,
          max: 400,
        }),
      );
      app.save(fichas);
    }
  },
  (app) => {
    const fichas = app.findCollectionByNameOrId('fichas_tecnicas');
    if (fichas.fields.getByName('temperatura_forno_c')) {
      fichas.fields.removeByName('temperatura_forno_c');
      app.save(fichas);
    }
  },
);
