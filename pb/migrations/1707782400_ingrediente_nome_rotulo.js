/// <reference path="../pb_data/types.d.ts" />

// `ingredientes.nome_rotulo`: nome curto/genérico do ingrediente para a lista
// resumida da etiqueta (ex.: "Chocolate Branco" em vez de "Chocolate Branco 30%
// Chocovic", "Framboesa" em vez de "Framboesa Congelada"). Opcional; vazio =
// a app deduz um nome curto sozinha.

migrate(
  (app) => {
    const c = app.findCollectionByNameOrId('ingredientes');
    if (!c.fields.getByName('nome_rotulo')) {
      c.fields.add(new Field({ type: 'text', name: 'nome_rotulo', required: false, max: 120 }));
      app.save(c);
    }
  },
  (app) => {
    const c = app.findCollectionByNameOrId('ingredientes');
    c.fields.removeByName('nome_rotulo');
    app.save(c);
  },
);
