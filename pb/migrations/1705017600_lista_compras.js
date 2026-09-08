/// <reference path="../pb_data/types.d.ts" />

// Fase 2 — `lista_compras`.

migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');
    const ingredientes = app.findCollectionByNameOrId('ingredientes');
    const producoes = app.findCollectionByNameOrId('producoes');

    const podeVer = "@request.auth.id != '' && empresa = @request.auth.empresa";
    const podeCriar =
      "@request.auth.id != '' && @request.body.empresa = @request.auth.empresa && @request.auth.papel != 'viewer'";
    const podeEscrever =
      "@request.auth.id != '' && empresa = @request.auth.empresa && @request.auth.papel != 'viewer'";

    const c = new Collection({
      type: 'base',
      name: 'lista_compras',
      listRule: podeVer,
      viewRule: podeVer,
      createRule: podeCriar,
      updateRule: podeEscrever,
      deleteRule: podeEscrever,
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
          type: 'relation',
          name: 'ingrediente',
          required: false,
          maxSelect: 1,
          collectionId: ingredientes.id,
          cascadeDelete: true,
        },
        { type: 'text', name: 'descricao', required: true, max: 200 },
        { type: 'text', name: 'fornecedor', required: false, max: 200 },
        {
          type: 'number',
          name: 'quantidade_necessaria_g',
          required: false,
          min: 0,
        },
        {
          type: 'number',
          name: 'quantidade_comprar_g',
          required: false,
          min: 0,
        },
        { type: 'bool', name: 'comprado', required: false },
        {
          type: 'relation',
          name: 'producao',
          required: false,
          maxSelect: 1,
          collectionId: producoes.id,
          cascadeDelete: false,
        },
      ],
      indexes: [
        'CREATE INDEX `idx_compras_empresa` ON `lista_compras` (`empresa`, `comprado`)',
      ],
    });
    c.fields.add(
      new Field({ type: 'autodate', name: 'created', onCreate: true }),
    );
    c.fields.add(
      new Field({
        type: 'autodate',
        name: 'updated',
        onCreate: true,
        onUpdate: true,
      }),
    );
    app.save(c);
  },
  (app) => {
    app.delete(app.findCollectionByNameOrId('lista_compras'));
  },
);
