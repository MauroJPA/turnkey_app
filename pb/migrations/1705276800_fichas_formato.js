/// <reference path="../pb_data/types.d.ts" />

// Fase 3 — `fichas_tecnicas.formato`: liga a ficha (produto acabado) ao
// formato de cookie, para a conclusão de produção creditar as unidades certas.

migrate(
  (app) => {
    const fichas = app.findCollectionByNameOrId('fichas_tecnicas');
    const formatos = app.findCollectionByNameOrId('formatos_cookie');
    if (!fichas.fields.getByName('formato')) {
      fichas.fields.add(
        new Field({
          type: 'relation',
          name: 'formato',
          required: false,
          maxSelect: 1,
          collectionId: formatos.id,
          cascadeDelete: false,
        }),
      );
      app.save(fichas);
    }
  },
  (app) => {
    const fichas = app.findCollectionByNameOrId('fichas_tecnicas');
    fichas.fields.removeByName('formato');
    app.save(fichas);
  },
);
