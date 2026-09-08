/// <reference path="../pb_data/types.d.ts" />

// Fase 5 — `faturas` (foto da fatura / lista de preços do fornecedor) e
// `faturas_itens` (linhas confirmadas que atualizam preço e/ou stock).
// A análise por IA e a aplicação são feitas pelos endpoints em
// pb/hooks/faturas.pb.js.

migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');
    const users = app.findCollectionByNameOrId('users');
    const ingredientes = app.findCollectionByNameOrId('ingredientes');

    const podeVer = "@request.auth.id != '' && empresa = @request.auth.empresa";
    const podeCriar =
      "@request.auth.id != '' && @request.body.empresa = @request.auth.empresa && @request.auth.papel != 'viewer'";
    const podeEscrever =
      "@request.auth.id != '' && empresa = @request.auth.empresa && @request.auth.papel != 'viewer'";

    const empresa = {
      type: 'relation',
      name: 'empresa',
      required: true,
      maxSelect: 1,
      collectionId: empresas.id,
      cascadeDelete: true,
    };
    const addCreated = (c) =>
      c.fields.add(
        new Field({ type: 'autodate', name: 'created', onCreate: true }),
      );

    const faturas = new Collection({
      type: 'base',
      name: 'faturas',
      listRule: podeVer,
      viewRule: podeVer,
      createRule: podeCriar,
      updateRule: podeEscrever,
      deleteRule: podeEscrever,
      fields: [
        empresa,
        {
          type: 'relation',
          name: 'autor',
          required: false,
          maxSelect: 1,
          collectionId: users.id,
          cascadeDelete: false,
        },
        {
          type: 'select',
          name: 'tipo',
          required: false,
          maxSelect: 1,
          values: ['fatura', 'lista_precos'],
        },
        { type: 'text', name: 'fornecedor', required: false, max: 200 },
        { type: 'date', name: 'data_fatura', required: false },
        { type: 'text', name: 'numero', required: false, max: 80 },
        { type: 'number', name: 'total', required: false, min: 0 },
        { type: 'number', name: 'iva', required: false, min: 0 },
        {
          type: 'file',
          name: 'ficheiro',
          required: false,
          maxSelect: 1,
          maxSize: 8388608,
          mimeTypes: [
            'image/jpeg',
            'image/png',
            'image/webp',
            'application/pdf',
          ],
          thumbs: ['0x240'],
        },
        {
          type: 'select',
          name: 'estado',
          required: false,
          maxSelect: 1,
          values: ['nova', 'analisada', 'confirmada', 'erro'],
        },
        { type: 'json', name: 'dados_ia', required: false, maxSize: 200000 },
        { type: 'text', name: 'notas', required: false, max: 500 },
      ],
      indexes: [
        'CREATE INDEX `idx_faturas_empresa` ON `faturas` (`empresa`, `data_fatura`)',
      ],
    });
    addCreated(faturas);
    app.save(faturas);

    const itens = new Collection({
      type: 'base',
      name: 'faturas_itens',
      listRule: podeVer,
      viewRule: podeVer,
      createRule: null,
      updateRule: null,
      deleteRule: null,
      fields: [
        empresa,
        {
          type: 'relation',
          name: 'fatura',
          required: true,
          maxSelect: 1,
          collectionId: faturas.id,
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
        { type: 'text', name: 'descricao_fatura', required: false, max: 300 },
        { type: 'number', name: 'quantidade_g', required: false, min: 0 },
        { type: 'number', name: 'preco_unitario', required: false, min: 0 },
        { type: 'number', name: 'total_linha', required: false, min: 0 },
        { type: 'number', name: 'embalagem_g', required: false, min: 0 },
        {
          type: 'select',
          name: 'acao',
          required: false,
          maxSelect: 1,
          values: ['preco', 'stock', 'ambos', 'ignorar'],
        },
        { type: 'bool', name: 'aplicado', required: false },
      ],
      indexes: [
        'CREATE INDEX `idx_faturas_itens_fatura` ON `faturas_itens` (`fatura`)',
      ],
    });
    addCreated(itens);
    app.save(itens);
  },
  (app) => {
    app.delete(app.findCollectionByNameOrId('faturas_itens'));
    app.delete(app.findCollectionByNameOrId('faturas'));
  },
);
