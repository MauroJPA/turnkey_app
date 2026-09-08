/// <reference path="../pb_data/types.d.ts" />

// Fase 2 — `inventario` (stock atual por item) e `movimentos_inventario`
// (histórico). Ambas só são escritas pelos endpoints do servidor
// (pb/hooks/inventario.pb.js), por isso create/update/delete = null.

migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');
    const ingredientes = app.findCollectionByNameOrId('ingredientes');
    const fichas = app.findCollectionByNameOrId('fichas_tecnicas');
    const users = app.findCollectionByNameOrId('users');

    const podeVer = "@request.auth.id != '' && empresa = @request.auth.empresa";

    const empresa = {
      type: 'relation',
      name: 'empresa',
      required: true,
      maxSelect: 1,
      collectionId: empresas.id,
      cascadeDelete: true,
    };
    const relIng = {
      type: 'relation',
      name: 'ingrediente',
      required: false,
      maxSelect: 1,
      collectionId: ingredientes.id,
      cascadeDelete: false,
    };
    const relFicha = {
      type: 'relation',
      name: 'ficha',
      required: false,
      maxSelect: 1,
      collectionId: fichas.id,
      cascadeDelete: false,
    };

    const addTimestamps = (col, comUpdated) => {
      col.fields.add(
        new Field({ type: 'autodate', name: 'created', onCreate: true }),
      );
      if (comUpdated) {
        col.fields.add(
          new Field({
            type: 'autodate',
            name: 'updated',
            onCreate: true,
            onUpdate: true,
          }),
        );
      }
    };

    // ---- inventario ---------------------------------------------------
    const inventario = new Collection({
      type: 'base',
      name: 'inventario',
      listRule: podeVer,
      viewRule: podeVer,
      createRule: null,
      updateRule: null,
      deleteRule: null,
      fields: [
        empresa,
        { ...relIng, cascadeDelete: true },
        { ...relFicha, cascadeDelete: true },
        { type: 'number', name: 'quantidade', required: false, min: 0 },
        { type: 'number', name: 'minimo', required: false, min: 0 },
        { type: 'text', name: 'localizacao', required: false, max: 120 },
      ],
      indexes: [
        "CREATE UNIQUE INDEX `idx_inv_ingrediente` ON `inventario` (`empresa`, `ingrediente`) WHERE `ingrediente` != ''",
        "CREATE UNIQUE INDEX `idx_inv_ficha` ON `inventario` (`empresa`, `ficha`) WHERE `ficha` != ''",
      ],
    });
    addTimestamps(inventario, true);
    app.save(inventario);

    // ---- movimentos_inventario ------------------------------------
    const movimentos = new Collection({
      type: 'base',
      name: 'movimentos_inventario',
      listRule: podeVer,
      viewRule: podeVer,
      createRule: null,
      updateRule: null,
      deleteRule: null,
      fields: [
        empresa,
        relIng,
        relFicha,
        { type: 'number', name: 'delta', required: true },
        {
          type: 'select',
          name: 'motivo',
          required: true,
          maxSelect: 1,
          values: [
            'compra',
            'consumo_producao',
            'saida_producao',
            'venda',
            'ajuste',
            'perda',
          ],
        },
        { type: 'text', name: 'notas', required: false, max: 300 },
        {
          type: 'relation',
          name: 'autor',
          required: false,
          maxSelect: 1,
          collectionId: users.id,
          cascadeDelete: false,
        },
        // `producao` (relation) é adicionada na migration das produções.
      ],
      indexes: [
        'CREATE INDEX `idx_mov_ingrediente` ON `movimentos_inventario` (`empresa`, `ingrediente`)',
        'CREATE INDEX `idx_mov_ficha` ON `movimentos_inventario` (`empresa`, `ficha`)',
      ],
    });
    addTimestamps(movimentos, false);
    app.save(movimentos);
  },
  (app) => {
    app.delete(app.findCollectionByNameOrId('movimentos_inventario'));
    app.delete(app.findCollectionByNameOrId('inventario'));
  },
);
