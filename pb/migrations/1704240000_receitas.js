/// <reference path="../pb_data/types.d.ts" />

// M3 — coleções `receitas` e `itens_receita`, e a relação
// `ingredientes.receita_espelho` (adiada do M2).

migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');
    const ingredientes = app.findCollectionByNameOrId('ingredientes');

    const podeEscrever =
      "@request.auth.id != '' && empresa = @request.auth.empresa && @request.auth.papel != 'viewer'";
    const podeCriar =
      "@request.auth.id != '' && @request.body.empresa = @request.auth.empresa && @request.auth.papel != 'viewer'";
    const podeVer =
      "@request.auth.id != '' && empresa = @request.auth.empresa";

    // ---- receitas ------------------------------------------------------
    const receitas = new Collection({
      type: 'base',
      name: 'receitas',
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
          name: 'categoria',
          required: true,
          maxSelect: 1,
          values: ['massa', 'recheio', 'cobertura', 'outra'],
        },
        { type: 'number', name: 'rendimento_esperado', required: false, min: 0 },
        { type: 'bool', name: 'rendimento_manual', required: false },
        { type: 'number', name: 'custo_receita', required: false, min: 0 },
        { type: 'number', name: 'custo_por_grama', required: false, min: 0 },
        { type: 'bool', name: 'publicar_como_ingrediente', required: false },
        { type: 'bool', name: 'deletado', required: false },
      ],
      indexes: [
        'CREATE INDEX `idx_receitas_empresa` ON `receitas` (`empresa`)',
      ],
    });
    app.save(receitas);

    // ---- itens_receita ----------------------------------------------
    const itens = new Collection({
      type: 'base',
      name: 'itens_receita',
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
          name: 'receita',
          required: true,
          maxSelect: 1,
          collectionId: receitas.id,
          cascadeDelete: true,
        },
        {
          type: 'relation',
          name: 'ingrediente',
          required: false,
          maxSelect: 1,
          collectionId: ingredientes.id,
          cascadeDelete: false,
        },
        {
          type: 'relation',
          name: 'sub_receita',
          required: false,
          maxSelect: 1,
          collectionId: receitas.id,
          cascadeDelete: false,
        },
        { type: 'number', name: 'quantidade_g', required: true, min: 0 },
        { type: 'text', name: 'nome_provisorio', required: false, max: 200 },
      ],
      indexes: [
        'CREATE INDEX `idx_itens_receita_receita` ON `itens_receita` (`receita`)',
        'CREATE INDEX `idx_itens_receita_ingrediente` ON `itens_receita` (`ingrediente`)',
        'CREATE INDEX `idx_itens_receita_sub` ON `itens_receita` (`sub_receita`)',
      ],
    });
    app.save(itens);

    // ---- ingredientes.receita_espelho ------------------------------
    ingredientes.fields.add(
      new Field({
        type: 'relation',
        name: 'receita_espelho',
        required: false,
        maxSelect: 1,
        collectionId: receitas.id,
        cascadeDelete: false,
      }),
    );
    app.save(ingredientes);
  },
  (app) => {
    const ingredientes = app.findCollectionByNameOrId('ingredientes');
    ingredientes.fields.removeByName('receita_espelho');
    app.save(ingredientes);
    app.delete(app.findCollectionByNameOrId('itens_receita'));
    app.delete(app.findCollectionByNameOrId('receitas'));
  },
);
