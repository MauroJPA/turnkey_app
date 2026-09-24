/// <reference path="../pb_data/types.d.ts" />

// `fichas_tecnicas.etiqueta_config`: definições de impressão da etiqueta deste
// produto (lista completa/resumida, nutrição, tamanhos…), guardadas para
// serem o predefinido nas próximas impressões.

migrate(
  (app) => {
    const c = app.findCollectionByNameOrId('fichas_tecnicas');
    if (!c.fields.getByName('etiqueta_config')) {
      c.fields.add(new Field({ type: 'json', name: 'etiqueta_config', required: false, maxSize: 5000 }));
      app.save(c);
    }
  },
  (app) => {
    const c = app.findCollectionByNameOrId('fichas_tecnicas');
    c.fields.removeByName('etiqueta_config');
    app.save(c);
  },
);
