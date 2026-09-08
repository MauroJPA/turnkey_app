/// <reference path="../pb_data/types.d.ts" />

// Fase 4 — `sugestoes`: qualquer utilizador pode enviar uma nota de erro ou
// melhoria a partir de qualquer página. Só os programadores leem (Admin UI).

migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');
    const users = app.findCollectionByNameOrId('users');

    const c = new Collection({
      type: 'base',
      name: 'sugestoes',
      // qualquer utilizador autenticado pode criar; ninguém lê pela API.
      listRule: null,
      viewRule: null,
      createRule: "@request.auth.id != ''",
      updateRule: null,
      deleteRule: null,
      fields: [
        {
          type: 'relation',
          name: 'empresa',
          required: false,
          maxSelect: 1,
          collectionId: empresas.id,
          cascadeDelete: false,
        },
        {
          type: 'relation',
          name: 'autor',
          required: false,
          maxSelect: 1,
          collectionId: users.id,
          cascadeDelete: false,
        },
        { type: 'text', name: 'pagina', required: false, max: 60 },
        { type: 'text', name: 'texto', required: true, max: 2000 },
        { type: 'text', name: 'contexto', required: false, max: 200 },
      ],
      indexes: [
        'CREATE INDEX `idx_sugestoes_created` ON `sugestoes` (`created`)',
      ],
    });
    c.fields.add(
      new Field({ type: 'autodate', name: 'created', onCreate: true }),
    );
    app.save(c);
  },
  (app) => {
    app.delete(app.findCollectionByNameOrId('sugestoes'));
  },
);
