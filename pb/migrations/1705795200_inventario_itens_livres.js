/// <reference path="../pb_data/types.d.ts" />

// Fase 4 — itens livres no inventário (não são ingredientes de receita nem
// fichas técnicas): sabão, sacos de lixo, uma tesoura, etc. Identificados
// por `descricao` (única por empresa) e contados numa `unidade`.

migrate(
  (app) => {
    for (const nome of ['inventario', 'movimentos_inventario']) {
      const c = app.findCollectionByNameOrId(nome);
      if (!c.fields.getByName('descricao')) {
        c.fields.add(
          new Field({
            type: 'text',
            name: 'descricao',
            required: false,
            max: 200,
          }),
        );
      }
      if (!c.fields.getByName('unidade')) {
        c.fields.add(
          new Field({ type: 'text', name: 'unidade', required: false, max: 20 }),
        );
      }
      app.save(c);
    }

    const inv = app.findCollectionByNameOrId('inventario');
    inv.indexes = inv.indexes.concat([
      "CREATE UNIQUE INDEX `idx_inv_descricao` ON `inventario` (`empresa`, `descricao`) WHERE `descricao` != ''",
    ]);
    app.save(inv);
  },
  (app) => {
    const inv = app.findCollectionByNameOrId('inventario');
    inv.indexes = inv.indexes.filter(
      (ix) => !ix.includes('idx_inv_descricao'),
    );
    app.save(inv);
    for (const nome of ['inventario', 'movimentos_inventario']) {
      const c = app.findCollectionByNameOrId(nome);
      c.fields.removeByName('descricao');
      c.fields.removeByName('unidade');
      app.save(c);
    }
  },
);
