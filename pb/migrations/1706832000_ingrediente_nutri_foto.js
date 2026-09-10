/// <reference path="../pb_data/types.d.ts" />

// Foto da tabela nutricional de um ingrediente (rótulo). Guardada como
// prova/referência de um preenchimento manual ou lido por IA. Serve para
// distinguir na lista os ingredientes "manual + com foto" dos "manual sem
// foto" e dos "do INSA".

migrate(
  (app) => {
    const c = app.findCollectionByNameOrId('ingredientes');
    if (!c.fields.getByName('nutri_foto')) {
      c.fields.add(
        new Field({
          type: 'file',
          name: 'nutri_foto',
          required: false,
          maxSelect: 1,
          maxSize: 8388608,
          mimeTypes: ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'],
          thumbs: ['0x240'],
        }),
      );
      app.save(c);
    }
  },
  (app) => {
    const c = app.findCollectionByNameOrId('ingredientes');
    if (c.fields.getByName('nutri_foto')) {
      c.fields.removeByName('nutri_foto');
      app.save(c);
    }
  },
);
