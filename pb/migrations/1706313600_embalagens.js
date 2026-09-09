/// <reference path="../pb_data/types.d.ts" />

// Embalagens (caixas, sacos, saquetas, adesivos, fita…) e o seu custo nas
// fichas técnicas. Uma peça pode servir várias unidades de produto
// (`rende_unidades`) — o custo por unidade de produto divide-se por esse valor.

migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');

    const podeVer = "@request.auth.id != '' && empresa = @request.auth.empresa";
    const podeCriar =
      "@request.auth.id != '' && @request.body.empresa = @request.auth.empresa && @request.auth.papel != 'viewer'";
    const podeEscrever =
      "@request.auth.id != '' && empresa = @request.auth.empresa && @request.auth.papel != 'viewer'";

    const c = new Collection({
      type: 'base',
      name: 'embalagens',
      listRule: podeVer,
      viewRule: podeVer,
      createRule: podeCriar,
      updateRule: podeEscrever,
      deleteRule: podeEscrever,
      fields: [
        {
          type: 'relation',
          name: 'empresa',
          required: true,
          maxSelect: 1,
          collectionId: empresas.id,
          cascadeDelete: true,
        },
        { type: 'text', name: 'nome', required: true, max: 200 },
        {
          type: 'select',
          name: 'tipo',
          required: false,
          maxSelect: 1,
          values: ['Caixa', 'Saco', 'Saqueta', 'Adesivo', 'Fita', 'Cartão', 'Outro'],
        },
        // € do que se compra (um rolo, um pacote, uma peça).
        { type: 'number', name: 'preco_compra', required: false, min: 0 },
        // quantas peças vêm nessa compra (rolo de 500 adesivos → 500).
        { type: 'number', name: 'unidades_compra', required: false, min: 0 },
        // quantas unidades de produto uma peça embala (caixa de 6 → 6).
        { type: 'number', name: 'rende_unidades', required: false, min: 0 },
        { type: 'text', name: 'fornecedor', required: false, max: 200 },
        // custo por unidade de produto, em cache (o hook mantém-no).
        { type: 'number', name: 'custo_unitario', required: false, min: 0 },
        { type: 'bool', name: 'deletado', required: false },
      ],
      indexes: [
        'CREATE INDEX `idx_embalagens_empresa` ON `embalagens` (`empresa`, `deletado`)',
      ],
    });
    c.fields.add(
      new Field({ type: 'autodate', name: 'created', onCreate: true }),
    );
    c.fields.add(
      new Field({
        type: 'autodate',
        name: 'updated',
        onCreate: true,
        onUpdate: true,
      }),
    );
    app.save(c);

    // itens_ficha: relação opcional para uma embalagem + slot 'embalagem'.
    const itens = app.findCollectionByNameOrId('itens_ficha');
    if (!itens.fields.getByName('embalagem')) {
      itens.fields.add(
        new Field({
          type: 'relation',
          name: 'embalagem',
          required: false,
          maxSelect: 1,
          collectionId: c.id,
          cascadeDelete: true,
        }),
      );
    }
    const slot = itens.fields.getByName('slot');
    if (slot && slot.values.indexOf('embalagem') < 0) {
      slot.values = slot.values.concat(['embalagem']);
    }
    app.save(itens);
  },
  (app) => {
    const itens = app.findCollectionByNameOrId('itens_ficha');
    itens.fields.removeByName('embalagem');
    const slot = itens.fields.getByName('slot');
    if (slot) slot.values = slot.values.filter((v) => v !== 'embalagem');
    app.save(itens);
    app.delete(app.findCollectionByNameOrId('embalagens'));
  },
);
