/// <reference path="../pb_data/types.d.ts" />

// `producao_itens.ficha`: o produto final (ficha técnica) escolhido em Produzir
// / Mise en place. Quando preenchido manda sobre a resolução automática
// massa + recheio + formato, e as unidades vêm do peso de massa por unidade
// da própria ficha.

migrate(
  (app) => {
    const itens = app.findCollectionByNameOrId('producao_itens');
    const fichas = app.findCollectionByNameOrId('fichas_tecnicas');
    if (!itens.fields.getByName('ficha')) {
      itens.fields.add(
        new Field({
          type: 'relation',
          name: 'ficha',
          required: false,
          maxSelect: 1,
          collectionId: fichas.id,
          cascadeDelete: false,
        }),
      );
      app.save(itens);
    }
  },
  (app) => {
    const itens = app.findCollectionByNameOrId('producao_itens');
    itens.fields.removeByName('ficha');
    app.save(itens);
  },
);
