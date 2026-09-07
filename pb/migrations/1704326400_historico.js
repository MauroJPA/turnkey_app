/// <reference path="../pb_data/types.d.ts" />

// M4 — coleção `historico` (registo de alterações de custo/peso).
// Só o servidor escreve (os hooks correm com privilégios de superuser);
// os utilizadores da empresa podem ler.

migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');
    const users = app.findCollectionByNameOrId('users');

    const historico = new Collection({
      type: 'base',
      name: 'historico',
      listRule: "@request.auth.id != '' && empresa = @request.auth.empresa",
      viewRule: "@request.auth.id != '' && empresa = @request.auth.empresa",
      createRule: null,
      updateRule: null,
      deleteRule: null,
      fields: [
        {
          type: 'relation',
          name: 'empresa',
          required: true,
          maxSelect: 1,
          collectionId: empresas.id,
          cascadeDelete: true,
        },
        {
          type: 'select',
          name: 'entidade_tipo',
          required: true,
          maxSelect: 1,
          values: ['ingrediente', 'receita', 'ficha'],
        },
        { type: 'text', name: 'entidade_id', required: true, max: 50 },
        { type: 'text', name: 'descricao', required: true, max: 500 },
        { type: 'json', name: 'valor_antes', maxSize: 200000 },
        { type: 'json', name: 'valor_depois', maxSize: 200000 },
        {
          type: 'relation',
          name: 'autor',
          required: false,
          maxSelect: 1,
          collectionId: users.id,
          cascadeDelete: false,
        },
      ],
      indexes: [
        'CREATE INDEX `idx_historico_entidade` ON `historico` (`empresa`, `entidade_tipo`, `entidade_id`)',
      ],
    });
    app.save(historico);
  },
  (app) => {
    app.delete(app.findCollectionByNameOrId('historico'));
  },
);
