/// <reference path="../pb_data/types.d.ts" />

// `empresas.rotulo_produtor`: nome e morada do produtor/embalador, impressos
// nas etiquetas dos produtos (menção obrigatória em pré-embalados).

migrate(
  (app) => {
    const c = app.findCollectionByNameOrId('empresas');
    if (!c.fields.getByName('rotulo_produtor')) {
      c.fields.add(new Field({ type: 'text', name: 'rotulo_produtor', required: false, max: 300 }));
      app.save(c);
    }
  },
  (app) => {
    const c = app.findCollectionByNameOrId('empresas');
    c.fields.removeByName('rotulo_produtor');
    app.save(c);
  },
);
