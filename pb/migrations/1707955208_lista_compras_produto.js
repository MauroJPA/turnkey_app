/// <reference path="../pb_data/types.d.ts" />

// Lista de compras: uma linha por PRODUTO de compra quando as receitas fixam
// produtos diferentes do mesmo ingrediente (ex.: farinha Sidul 1 kg numa
// receita e farinha Makro 5 kg noutra). `produto` vazio = ingrediente em
// automático (embalagem do genérico).

migrate(
  (app) => {
    const produtos = app.findCollectionByNameOrId('ingrediente_produtos');
    const lista = app.findCollectionByNameOrId('lista_compras');
    lista.fields.add(
      new Field({
        type: 'relation',
        name: 'produto',
        required: false,
        maxSelect: 1,
        collectionId: produtos.id,
        cascadeDelete: false,
      }),
    );
    const clausula =
      "(@request.body.produto:isset = false || @request.body.produto = '' || " +
      '@request.body.produto.empresa = @request.auth.empresa)';
    if (lista.createRule) lista.createRule = '(' + lista.createRule + ') && ' + clausula;
    if (lista.updateRule) lista.updateRule = '(' + lista.updateRule + ') && ' + clausula;
    app.save(lista);
  },
  (app) => {
    const lista = app.findCollectionByNameOrId('lista_compras');
    lista.fields.removeByName('produto');
    const tirar = (r) => {
      if (!r) return r;
      const i = r.lastIndexOf(' && (@request.body.produto:isset');
      return i < 0 ? r : r.substring(0, i).replace(/^\((.*)\)$/, '$1');
    };
    lista.createRule = tirar(lista.createRule);
    lista.updateRule = tirar(lista.updateRule);
    app.save(lista);
  },
);
