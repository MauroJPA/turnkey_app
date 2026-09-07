/// <reference path="../pb_data/types.d.ts" />

// Adiciona campos autodate `created` / `updated` às coleções de negócio
// (as coleções base do PocketBase não os trazem por omissão, e sem eles não
// é possível ordenar por data nem no cliente nem nos hooks).

const ALVOS = [
  'empresas',
  'configuracoes_custo',
  'ingredientes',
  'receitas',
  'itens_receita',
  'historico',
];

migrate(
  (app) => {
    for (const nome of ALVOS) {
      const col = app.findCollectionByNameOrId(nome);
      if (!col.fields.getByName('created')) {
        col.fields.add(
          new Field({ type: 'autodate', name: 'created', onCreate: true }),
        );
      }
      if (!col.fields.getByName('updated')) {
        col.fields.add(
          new Field({
            type: 'autodate',
            name: 'updated',
            onCreate: true,
            onUpdate: true,
          }),
        );
      }
      app.save(col);
    }
  },
  (app) => {
    for (const nome of ALVOS) {
      const col = app.findCollectionByNameOrId(nome);
      col.fields.removeByName('created');
      col.fields.removeByName('updated');
      app.save(col);
    }
  },
);
