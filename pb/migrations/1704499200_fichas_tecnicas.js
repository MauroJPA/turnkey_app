/// <reference path="../pb_data/types.d.ts" />

// M5 — coleções `fichas_tecnicas` e `itens_ficha` (produtos finais).

migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');
    const ingredientes = app.findCollectionByNameOrId('ingredientes');
    const receitas = app.findCollectionByNameOrId('receitas');

    const podeVer =
      "@request.auth.id != '' && empresa = @request.auth.empresa";
    const podeCriar =
      "@request.auth.id != '' && @request.body.empresa = @request.auth.empresa && @request.auth.papel != 'viewer'";
    const podeEscrever =
      "@request.auth.id != '' && empresa = @request.auth.empresa && @request.auth.papel != 'viewer'";

    const created = new Field({
      type: 'autodate',
      name: 'created',
      onCreate: true,
    });
    const updated = new Field({
      type: 'autodate',
      name: 'updated',
      onCreate: true,
      onUpdate: true,
    });

    const fichas = new Collection({
      type: 'base',
      name: 'fichas_tecnicas',
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
        { type: 'text', name: 'nome', required: true, max: 200 },
        { type: 'text', name: 'categoria', required: false, max: 100 },
        { type: 'number', name: 'custo_produto', required: false, min: 0 },
        { type: 'number', name: 'peso_produto', required: false, min: 0 },
        { type: 'bool', name: 'deletado', required: false },
      ],
      indexes: [
        'CREATE INDEX `idx_fichas_empresa` ON `fichas_tecnicas` (`empresa`)',
      ],
    });
    fichas.fields.add(created);
    fichas.fields.add(updated);
    app.save(fichas);

    const itens = new Collection({
      type: 'base',
      name: 'itens_ficha',
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
          name: 'ficha',
          required: true,
          maxSelect: 1,
          collectionId: fichas.id,
          cascadeDelete: true,
        },
        {
          type: 'relation',
          name: 'ingrediente',
          required: false,
          maxSelect: 1,
          collectionId: ingredientes.id,
          cascadeDelete: false,
        },
        {
          type: 'relation',
          name: 'receita',
          required: false,
          maxSelect: 1,
          collectionId: receitas.id,
          cascadeDelete: false,
        },
        { type: 'number', name: 'quantidade_g', required: true, min: 0 },
        {
          type: 'select',
          name: 'slot',
          required: true,
          maxSelect: 1,
          values: [
            'massa',
            'recheio_base',
            'recheio_top',
            'cobertura_base',
            'cobertura_top',
            'extra',
          ],
        },
      ],
      indexes: [
        'CREATE INDEX `idx_itens_ficha_ficha` ON `itens_ficha` (`ficha`)',
        'CREATE INDEX `idx_itens_ficha_ingrediente` ON `itens_ficha` (`ingrediente`)',
        'CREATE INDEX `idx_itens_ficha_receita` ON `itens_ficha` (`receita`)',
      ],
    });
    itens.fields.add(
      new Field({ type: 'autodate', name: 'created', onCreate: true }),
    );
    itens.fields.add(
      new Field({
        type: 'autodate',
        name: 'updated',
        onCreate: true,
        onUpdate: true,
      }),
    );
    app.save(itens);
  },
  (app) => {
    app.delete(app.findCollectionByNameOrId('itens_ficha'));
    app.delete(app.findCollectionByNameOrId('fichas_tecnicas'));
  },
);
