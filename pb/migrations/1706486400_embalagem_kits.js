/// <reference path="../pb_data/types.d.ts" />

// Kits de embalagens: um conjunto nomeado de embalagens + quantidades
// (ex.: "Take-away" = 1 saqueta + 1 caixa individual + 1 saco + 2 adesivos).
// Na ficha técnica escolhe-se um kit no slot de embalagem para precificar de
// uma vez. O custo do kit = soma de (custo por unidade de cada embalagem ×
// quantidade). Mantido em cache em `custo_unitario` pelo hook.

migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');
    const embalagens = app.findCollectionByNameOrId('embalagens');

    const podeVer =
      "@request.auth.id != '' && empresa = @request.auth.empresa";
    const podeCriar =
      "@request.auth.id != '' && @request.body.empresa = @request.auth.empresa && @request.auth.papel != 'viewer'";
    const podeEscrever =
      "@request.auth.id != '' && empresa = @request.auth.empresa && @request.auth.papel != 'viewer'";

    const kits = new Collection({
      type: 'base',
      name: 'embalagem_kits',
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
        { type: 'text', name: 'descricao', required: false, max: 300 },
        // custo por unidade de produto (soma das linhas), em cache.
        { type: 'number', name: 'custo_unitario', required: false, min: 0 },
        { type: 'bool', name: 'deletado', required: false },
      ],
      indexes: [
        'CREATE INDEX `idx_embalagem_kits_empresa` ON `embalagem_kits` (`empresa`, `deletado`)',
      ],
    });
    kits.fields.add(
      new Field({ type: 'autodate', name: 'created', onCreate: true }),
    );
    kits.fields.add(
      new Field({
        type: 'autodate',
        name: 'updated',
        onCreate: true,
        onUpdate: true,
      }),
    );
    app.save(kits);

    const kitItens = new Collection({
      type: 'base',
      name: 'embalagem_kit_itens',
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
        {
          type: 'relation',
          name: 'kit',
          required: true,
          maxSelect: 1,
          collectionId: kits.id,
          cascadeDelete: true,
        },
        {
          type: 'relation',
          name: 'embalagem',
          required: true,
          maxSelect: 1,
          collectionId: embalagens.id,
          cascadeDelete: true,
        },
        { type: 'number', name: 'quantidade', required: true, min: 0 },
      ],
      indexes: [
        'CREATE INDEX `idx_embalagem_kit_itens_kit` ON `embalagem_kit_itens` (`kit`)',
        'CREATE INDEX `idx_embalagem_kit_itens_emb` ON `embalagem_kit_itens` (`embalagem`)',
      ],
    });
    kitItens.fields.add(
      new Field({ type: 'autodate', name: 'created', onCreate: true }),
    );
    app.save(kitItens);

    // itens_ficha: relação opcional para um kit de embalagens.
    const itens = app.findCollectionByNameOrId('itens_ficha');
    if (!itens.fields.getByName('kit')) {
      itens.fields.add(
        new Field({
          type: 'relation',
          name: 'kit',
          required: false,
          maxSelect: 1,
          collectionId: kits.id,
          cascadeDelete: true,
        }),
      );
      app.save(itens);
    }
  },
  (app) => {
    const itens = app.findCollectionByNameOrId('itens_ficha');
    if (itens.fields.getByName('kit')) {
      itens.fields.removeByName('kit');
      app.save(itens);
    }
    app.delete(app.findCollectionByNameOrId('embalagem_kit_itens'));
    app.delete(app.findCollectionByNameOrId('embalagem_kits'));
  },
);
