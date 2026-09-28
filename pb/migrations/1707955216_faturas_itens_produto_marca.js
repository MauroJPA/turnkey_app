/// <reference path="../pb_data/types.d.ts" />

// `faturas_itens` passa a guardar A QUE PRODUTO de compra (marca) escreveu o
// preço/marca/fornecedor, e a própria marca/fornecedor que ficaram gravados —
// para dar para corrigir depois (ver pb/hooks/faturas_corrigir.pb.js e
// /api/gc_turnkey/faturas/{id}/corrigir-item). Sem isto, uma vez aplicada a
// linha, não havia como saber qual `ingrediente_produtos` tinha sido tocado
// nem que marca/fornecedor lá ficaram, para os rever olhando a fatura depois.
//
// `createRule`/`updateRule` de `faturas_itens` são `null` (só o servidor
// escreve, via endpoint) — não precisa da cláusula de "mesma empresa" que as
// relações editáveis pela API costumam ter.

migrate(
  (app) => {
    const itens = app.findCollectionByNameOrId('faturas_itens');
    const produtos = app.findCollectionByNameOrId('ingrediente_produtos');
    if (!itens.fields.getByName('produto')) {
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
    }
    if (!itens.fields.getByName('marca')) {
      itens.fields.add(new Field({ type: 'text', name: 'marca', required: false, max: 200 }));
    }
    if (!itens.fields.getByName('fornecedor')) {
      itens.fields.add(new Field({ type: 'text', name: 'fornecedor', required: false, max: 200 }));
    }
    app.save(itens);
  },
  (app) => {
    const itens = app.findCollectionByNameOrId('faturas_itens');
    itens.fields.removeByName('produto');
    itens.fields.removeByName('marca');
    itens.fields.removeByName('fornecedor');
    app.save(itens);
  },
);
