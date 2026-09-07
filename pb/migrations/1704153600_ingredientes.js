/// <reference path="../pb_data/types.d.ts" />

// M2 — coleção `ingredientes`.
// (a relação `receita_espelho` -> receitas é adicionada na migration do M3,
//  quando a coleção `receitas` já existe.)

migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');

    const ingredientes = new Collection({
      type: 'base',
      name: 'ingredientes',
      listRule: "@request.auth.id != '' && empresa = @request.auth.empresa",
      viewRule: "@request.auth.id != '' && empresa = @request.auth.empresa",
      createRule:
        "@request.auth.id != '' && @request.body.empresa = @request.auth.empresa && @request.auth.papel != 'viewer'",
      updateRule:
        "@request.auth.id != '' && empresa = @request.auth.empresa && @request.auth.papel != 'viewer'",
      deleteRule:
        "@request.auth.id != '' && empresa = @request.auth.empresa && @request.auth.papel != 'viewer'",
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
        { type: 'text', name: 'caracteristica', required: false, max: 200 },
        { type: 'text', name: 'marca', required: false, max: 200 },
        { type: 'text', name: 'fornecedor', required: false, max: 200 },
        { type: 'number', name: 'preco', required: false, min: 0 },
        { type: 'number', name: 'gramas_embalagem', required: false, min: 0 },
        { type: 'date', name: 'preco_atualizado_em', required: false },
        { type: 'bool', name: 'disponivel', required: false },
        {
          type: 'select',
          name: 'origem',
          required: true,
          maxSelect: 1,
          values: ['comprado', 'fabrico_proprio'],
        },
        // custo por grama em cache (o hook do M4 passa a mantê-lo;
        // até lá o cliente calcula para exibição)
        { type: 'number', name: 'custo_por_grama', required: false, min: 0 },
        { type: 'bool', name: 'deletado', required: false },
      ],
      indexes: [
        'CREATE INDEX `idx_ingredientes_empresa` ON `ingredientes` (`empresa`)',
        'CREATE INDEX `idx_ingredientes_nome` ON `ingredientes` (`empresa`, `nome`)',
      ],
    });
    app.save(ingredientes);
  },
  (app) => {
    app.delete(app.findCollectionByNameOrId('ingredientes'));
  },
);
