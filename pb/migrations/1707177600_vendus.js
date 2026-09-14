/// <reference path="../pb_data/types.d.ts" />

// Financeiro (F-FIN-6) — sincronização com o Vendus (POS/faturação que a
// Gookie usa). `vendas.vendus_id` identifica o documento de origem no
// Vendus, para não importar o mesmo documento duas vezes; índice único
// (por empresa) só quando não está vazio, para não afetar as vendas
// manuais/CSV (que não têm `vendus_id`).
// `empresas.vendus_ultima_sincronizacao` guarda a data do documento mais
// recente já importado, para a sincronização seguinte só pedir ao Vendus o
// que é novo.

migrate(
  (app) => {
    const vendas = app.findCollectionByNameOrId('vendas');
    if (!vendas.fields.getByName('vendus_id')) {
      vendas.fields.add(
        new Field({ type: 'text', name: 'vendus_id', required: false, max: 100 }),
      );
      vendas.indexes = vendas.indexes.concat([
        'CREATE UNIQUE INDEX `idx_vendas_vendus_id` ON `vendas` (`empresa`, `vendus_id`) WHERE `vendus_id` != \'\'',
      ]);
      app.save(vendas);
    }

    const empresas = app.findCollectionByNameOrId('empresas');
    if (!empresas.fields.getByName('vendus_ultima_sincronizacao')) {
      empresas.fields.add(
        new Field({
          type: 'text',
          name: 'vendus_ultima_sincronizacao',
          required: false,
          max: 40,
        }),
      );
      app.save(empresas);
    }
  },
  (app) => {
    const vendas = app.findCollectionByNameOrId('vendas');
    if (vendas.fields.getByName('vendus_id')) {
      vendas.fields.removeByName('vendus_id');
      vendas.indexes = vendas.indexes.filter(
        (i) => !i.includes('idx_vendas_vendus_id'),
      );
      app.save(vendas);
    }

    const empresas = app.findCollectionByNameOrId('empresas');
    if (empresas.fields.getByName('vendus_ultima_sincronizacao')) {
      empresas.fields.removeByName('vendus_ultima_sincronizacao');
      app.save(empresas);
    }
  },
);
