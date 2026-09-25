/// <reference path="../pb_data/types.d.ts" />

// Linha de receita com produto de compra fixado: além do ingrediente genérico
// ("Açúcar branco"), a linha pode escolher UM produto ("Sidul 1 kg"). Sem
// produto, a linha usa o custo do genérico (compra mais recente). O custo por
// grama da linha vem do produto fixado (ver cascade.js, cpgLinha).

migrate(
  (app) => {
    const produtos = app.findCollectionByNameOrId('ingrediente_produtos');
    const itens = app.findCollectionByNameOrId('itens_receita');
    itens.fields.add(
      new Field({
        type: 'relation',
        name: 'produto',
        required: false,
        maxSelect: 1,
        collectionId: produtos.id,
        cascadeDelete: false,
      }),
    );
    // o produto tem de ser da mesma empresa (como as restantes relações)
    const clausula =
      "(@request.body.produto:isset = false || @request.body.produto = '' || " +
      '@request.body.produto.empresa = @request.auth.empresa)';
    itens.createRule = '(' + itens.createRule + ') && ' + clausula;
    itens.updateRule = '(' + itens.updateRule + ') && ' + clausula;
    app.save(itens);
  },
  (app) => {
    const itens = app.findCollectionByNameOrId('itens_receita');
    itens.fields.removeByName('produto');
    const tirar = (r) => {
      const i = r.lastIndexOf(' && (@request.body.produto:isset');
      return i < 0 ? r : r.substring(0, i).replace(/^\((.*)\)$/, '$1');
    };
    itens.createRule = tirar(itens.createRule);
    itens.updateRule = tirar(itens.updateRule);
    app.save(itens);
  },
);
