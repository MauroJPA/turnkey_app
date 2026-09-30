/// <reference path="../pb_data/types.d.ts" />

// Texto livre com a declaração de aditivos deste ingrediente (ex.: "Corante:
// E122, E110 (pode ter efeitos negativos na atividade e atenção das
// crianças). Conservante: E211."), para entrar automaticamente na lista de
// ingredientes do produto final (ver lista_ingredientes.dart) — separado da
// nutrição/alergénios, porque a obrigação de o declarar não depende da
// quantidade usada nem tem nada a ver com valores nutricionais.
migrate(
  (app) => {
    const ing = app.findCollectionByNameOrId('ingredientes');
    if (!ing.fields.getByName('aditivos')) {
      ing.fields.add(
        new Field({
          type: 'text',
          name: 'aditivos',
          required: false,
          max: 500,
        }),
      );
      app.save(ing);
    }
  },
  (app) => {
    const ing = app.findCollectionByNameOrId('ingredientes');
    if (ing.fields.getByName('aditivos')) {
      ing.fields.removeByName('aditivos');
      app.save(ing);
    }
  },
);
