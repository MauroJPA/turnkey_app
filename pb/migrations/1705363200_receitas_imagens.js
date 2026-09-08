/// <reference path="../pb_data/types.d.ts" />

// Fase 3 — `receitas.imagens`: fotos do passo-a-passo / resultado da receita.
// O campo `procedimento` (texto) já existe (1704758400_receita_procedimento.js).

migrate(
  (app) => {
    const c = app.findCollectionByNameOrId('receitas');
    if (!c.fields.getByName('imagens')) {
      c.fields.add(
        new Field({
          type: 'file',
          name: 'imagens',
          required: false,
          maxSelect: 8,
          maxSize: 5242880,
          mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
          thumbs: ['0x160'],
        }),
      );
      app.save(c);
    }
  },
  (app) => {
    const c = app.findCollectionByNameOrId('receitas');
    c.fields.removeByName('imagens');
    app.save(c);
  },
);
