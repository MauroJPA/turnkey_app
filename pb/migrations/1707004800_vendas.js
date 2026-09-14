/// <reference path="../pb_data/types.d.ts" />

// Financeiro (F-FIN-1) — registo de vendas (base do painel financeiro, DRE e
// análise de sabores mais vendidos). `vendas` = uma venda (dia/documento);
// `vendas_itens` = as linhas (produto/quantidade/preço), opcionalmente
// ligadas a uma `fichas_tecnicas` para poder agregar por sabor/produto.
// Também adiciona `fichas_tecnicas.preco_venda` (preço real definido pelo
// utilizador — até agora só existia o preço *sugerido*, calculado ao vivo a
// partir de `configuracoes_custo`, nunca persistido).

migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');
    const fichas = app.findCollectionByNameOrId('fichas_tecnicas');

    // --- fichas_tecnicas.preco_venda ------------------------------------
    if (!fichas.fields.getByName('preco_venda')) {
      fichas.fields.add(
        new Field({ type: 'number', name: 'preco_venda', required: false, min: 0 }),
      );
      app.save(fichas);
    }

    const podeVer = "@request.auth.id != '' && empresa = @request.auth.empresa";
    const podeCriar =
      "@request.auth.id != '' && @request.body.empresa = @request.auth.empresa && @request.auth.papel != 'viewer'";
    const podeEscrever =
      "@request.auth.id != '' && empresa = @request.auth.empresa && @request.auth.papel != 'viewer'";

    const campoEmpresa = () => ({
      type: 'relation',
      name: 'empresa',
      required: true,
      maxSelect: 1,
      collectionId: empresas.id,
      cascadeDelete: true,
    });
    const addCreated = (c) =>
      c.fields.add(new Field({ type: 'autodate', name: 'created', onCreate: true }));
    const addUpdated = (c) =>
      c.fields.add(
        new Field({ type: 'autodate', name: 'updated', onCreate: true, onUpdate: true }),
      );

    // --- vendas ----------------------------------------------------------
    const vendas = new Collection({
      type: 'base',
      name: 'vendas',
      listRule: podeVer,
      viewRule: podeVer,
      createRule: podeCriar,
      updateRule: podeEscrever,
      deleteRule: podeEscrever,
      fields: [
        campoEmpresa(),
        { type: 'date', name: 'data', required: true },
        {
          type: 'select',
          name: 'origem',
          required: true,
          maxSelect: 1,
          values: ['manual', 'csv', 'vendus'],
        },
        { type: 'number', name: 'total', required: false, min: 0 },
        { type: 'text', name: 'numero_documento', required: false, max: 60 },
        { type: 'text', name: 'notas', required: false, max: 500 },
        {
          type: 'relation',
          name: 'autor',
          required: false,
          maxSelect: 1,
          collectionId: app.findCollectionByNameOrId('users').id,
          cascadeDelete: false,
        },
      ],
      indexes: ['CREATE INDEX `idx_vendas_empresa_data` ON `vendas` (`empresa`, `data`)'],
    });
    addCreated(vendas);
    addUpdated(vendas);
    app.save(vendas);

    // --- vendas_itens ------------------------------------------------------
    const vendasItens = new Collection({
      type: 'base',
      name: 'vendas_itens',
      listRule: podeVer,
      viewRule: podeVer,
      createRule: podeCriar,
      updateRule: podeEscrever,
      deleteRule: podeEscrever,
      fields: [
        campoEmpresa(),
        {
          type: 'relation',
          name: 'venda',
          required: true,
          maxSelect: 1,
          collectionId: vendas.id,
          cascadeDelete: true,
        },
        {
          type: 'relation',
          name: 'ficha',
          required: false,
          maxSelect: 1,
          collectionId: fichas.id,
          cascadeDelete: false,
        },
        { type: 'text', name: 'descricao', required: false, max: 200 },
        { type: 'number', name: 'quantidade', required: true, min: 0 },
        { type: 'number', name: 'preco_unitario', required: true, min: 0 },
        { type: 'number', name: 'total_linha', required: false, min: 0 },
        { type: 'number', name: 'custo_unitario_snapshot', required: false, min: 0 },
      ],
      indexes: [
        'CREATE INDEX `idx_vendas_itens_venda` ON `vendas_itens` (`venda`)',
        'CREATE INDEX `idx_vendas_itens_ficha` ON `vendas_itens` (`ficha`)',
      ],
    });
    addCreated(vendasItens);
    app.save(vendasItens);

    // --- historico: nova entidade "venda" -------------------------------
    const historico = app.findCollectionByNameOrId('historico');
    const entidadeTipo = historico.fields.getByName('entidade_tipo');
    if (entidadeTipo && !entidadeTipo.values.includes('venda')) {
      entidadeTipo.values = entidadeTipo.values.concat(['venda']);
      app.save(historico);
    }
  },
  (app) => {
    app.delete(app.findCollectionByNameOrId('vendas_itens'));
    app.delete(app.findCollectionByNameOrId('vendas'));

    const fichas = app.findCollectionByNameOrId('fichas_tecnicas');
    if (fichas.fields.getByName('preco_venda')) {
      fichas.fields.removeByName('preco_venda');
      app.save(fichas);
    }
  },
);
