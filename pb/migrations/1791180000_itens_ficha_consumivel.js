/// <reference path="../pb_data/types.d.ts" />

// Revenda a partir do Inventário → Limpeza e insumos (2.22.1).
//
// As bebidas e outros produtos de revenda entram pelas faturas como
// `consumiveis` (categoria Bebida/Revenda), com `preco` por unidade. Uma linha
// de ficha (`itens_ficha`) passa a poder apontar para um consumível: o custo
// da linha é preco × quantidade (unidades) e atualiza-se quando o preço muda.
// Como nas outras ligações, o consumível tem de ser da mesma empresa.
migrate(
  (app) => {
    const consumiveis = app.findCollectionByNameOrId('consumiveis');
    const itens = app.findCollectionByNameOrId('itens_ficha');
    if (!itens.fields.getByName('consumivel')) {
      itens.fields.add(
        new RelationField({ name: 'consumivel', required: false, maxSelect: 1, collectionId: consumiveis.id, cascadeDelete: true }),
      );
    }
    const clausula =
      "(@request.body.consumivel:isset = false || @request.body.consumivel = '' || @request.body.consumivel.empresa = @request.auth.empresa)";
    itens.createRule = '(' + itens.createRule + ') && ' + clausula;
    itens.updateRule = '(' + itens.updateRule + ') && ' + clausula;
    app.save(itens);
  },
  (app) => {
    const itens = app.findCollectionByNameOrId('itens_ficha');
    const clausula =
      " && (@request.body.consumivel:isset = false || @request.body.consumivel = '' || @request.body.consumivel.empresa = @request.auth.empresa)";
    const tirar = (r) => {
      const s = String(r || '').replace(clausula, '');
      return s.startsWith('(') && s.endsWith(')') ? s.slice(1, -1) : s;
    };
    itens.createRule = tirar(itens.createRule);
    itens.updateRule = tirar(itens.updateRule);
    itens.fields.removeByName('consumivel');
    app.save(itens);
  },
);
