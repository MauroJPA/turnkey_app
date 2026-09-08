/// <reference path="../pb_data/types.d.ts" />

// Fase 2 — `producoes` (plano de produção com data) e `producao_itens`
// (receitas + kg). Também liga a relação `producao` em movimentos_inventario.

migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');
    const receitas = app.findCollectionByNameOrId('receitas');

    const podeVer = "@request.auth.id != '' && empresa = @request.auth.empresa";
    const podeCriar =
      "@request.auth.id != '' && @request.body.empresa = @request.auth.empresa && @request.auth.papel != 'viewer'";
    const podeEscrever =
      "@request.auth.id != '' && empresa = @request.auth.empresa && @request.auth.papel != 'viewer'";

    const empresa = {
      type: 'relation',
      name: 'empresa',
      required: true,
      maxSelect: 1,
      collectionId: empresas.id,
      cascadeDelete: true,
    };
    const addTimestamps = (col) => {
      col.fields.add(
        new Field({ type: 'autodate', name: 'created', onCreate: true }),
      );
      col.fields.add(
        new Field({
          type: 'autodate',
          name: 'updated',
          onCreate: true,
          onUpdate: true,
        }),
      );
    };

    const producoes = new Collection({
      type: 'base',
      name: 'producoes',
      listRule: podeVer,
      viewRule: podeVer,
      createRule: podeCriar,
      updateRule: podeEscrever,
      deleteRule: podeEscrever,
      fields: [
        empresa,
        { type: 'date', name: 'data', required: true },
        { type: 'text', name: 'titulo', required: false, max: 200 },
        {
          type: 'select',
          name: 'estado',
          required: true,
          maxSelect: 1,
          values: ['planeada', 'concluida', 'cancelada'],
        },
        { type: 'text', name: 'notas', required: false, max: 500 },
        { type: 'date', name: 'concluida_em', required: false },
        { type: 'number', name: 'custo_snapshot', required: false, min: 0 },
      ],
      indexes: [
        'CREATE INDEX `idx_producoes_data` ON `producoes` (`empresa`, `data`)',
      ],
    });
    addTimestamps(producoes);
    app.save(producoes);

    const itens = new Collection({
      type: 'base',
      name: 'producao_itens',
      listRule: podeVer,
      viewRule: podeVer,
      createRule: podeCriar,
      updateRule: podeEscrever,
      deleteRule: podeEscrever,
      fields: [
        empresa,
        {
          type: 'relation',
          name: 'producao',
          required: true,
          maxSelect: 1,
          collectionId: producoes.id,
          cascadeDelete: true,
        },
        {
          type: 'relation',
          name: 'receita',
          required: true,
          maxSelect: 1,
          collectionId: receitas.id,
          cascadeDelete: false,
        },
        { type: 'number', name: 'quantidade_kg', required: true, min: 0 },
      ],
      indexes: [
        'CREATE INDEX `idx_prod_itens_producao` ON `producao_itens` (`producao`)',
      ],
    });
    addTimestamps(itens);
    app.save(itens);

    // ligar movimentos_inventario.producao
    const mov = app.findCollectionByNameOrId('movimentos_inventario');
    if (!mov.fields.getByName('producao')) {
      mov.fields.add(
        new Field({
          type: 'relation',
          name: 'producao',
          required: false,
          maxSelect: 1,
          collectionId: producoes.id,
          cascadeDelete: false,
        }),
      );
      app.save(mov);
    }
  },
  (app) => {
    const mov = app.findCollectionByNameOrId('movimentos_inventario');
    mov.fields.removeByName('producao');
    app.save(mov);
    app.delete(app.findCollectionByNameOrId('producao_itens'));
    app.delete(app.findCollectionByNameOrId('producoes'));
  },
);
