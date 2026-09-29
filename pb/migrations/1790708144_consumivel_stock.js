/// <reference path="../pb_data/types.d.ts" />

// Stock para Bebida/Revenda/Limpeza/Insumo (coleção `consumiveis`), tal como
// já existe para `ingredientes`: uma característica para distinguir variantes
// (ex. "detergente 1L" vs. "5L") e entrada de stock no `inventario` /
// `movimentos_inventario` ao aplicar uma fatura com ação "Stock"/"Ambos".

migrate(
  (app) => {
    const cons = app.findCollectionByNameOrId('consumiveis');
    if (!cons.fields.getByName('caracteristica')) {
      cons.fields.add(
        new Field({
          type: 'text',
          name: 'caracteristica',
          required: false,
          max: 200,
        }),
      );
    }
    app.save(cons);

    const inventario = app.findCollectionByNameOrId('inventario');
    if (!inventario.fields.getByName('consumivel')) {
      inventario.fields.add(
        new Field({
          type: 'relation',
          name: 'consumivel',
          required: false,
          maxSelect: 1,
          collectionId: cons.id,
          cascadeDelete: true,
        }),
      );
      inventario.indexes.push(
        "CREATE UNIQUE INDEX `idx_inv_consumivel` ON `inventario` (`empresa`, `consumivel`) WHERE `consumivel` != ''",
      );
    }
    app.save(inventario);

    const movimentos = app.findCollectionByNameOrId('movimentos_inventario');
    if (!movimentos.fields.getByName('consumivel')) {
      movimentos.fields.add(
        new Field({
          type: 'relation',
          name: 'consumivel',
          required: false,
          maxSelect: 1,
          collectionId: cons.id,
          cascadeDelete: false,
        }),
      );
      movimentos.indexes.push(
        'CREATE INDEX `idx_mov_consumivel` ON `movimentos_inventario` (`empresa`, `consumivel`)',
      );
    }
    app.save(movimentos);
  },
  (app) => {
    const movimentos = app.findCollectionByNameOrId('movimentos_inventario');
    movimentos.indexes = movimentos.indexes.filter(
      (i) => i.indexOf('idx_mov_consumivel') === -1,
    );
    movimentos.fields.removeByName('consumivel');
    app.save(movimentos);

    const inventario = app.findCollectionByNameOrId('inventario');
    inventario.indexes = inventario.indexes.filter(
      (i) => i.indexOf('idx_inv_consumivel') === -1,
    );
    inventario.fields.removeByName('consumivel');
    app.save(inventario);

    const cons = app.findCollectionByNameOrId('consumiveis');
    cons.fields.removeByName('caracteristica');
    app.save(cons);
  },
);
