/// <reference path="../pb_data/types.d.ts" />

// Rastreabilidade por lote (Reg. (CE) 178/2002, art. 18: "um passo atrás").
//
// `lotes_ingrediente`: o lote de um ingrediente recebido (código impresso na
//   embalagem do fornecedor, validade, fornecedor, fatura de compra).
// `lotes_producao`: um lote de produto acabado — código próprio (vai na
//   etiqueta e no QR), data, quantidade, validade e a lista (cópia) dos lotes
//   de ingredientes usados, para a consulta continuar certa mesmo que se apague
//   o ingrediente. Apagar um lote de produção só o proprietário/administrador.
migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');
    const ingredientes = app.findCollectionByNameOrId('ingredientes');
    const fichas = app.findCollectionByNameOrId('fichas_tecnicas');
    const faturas = app.findCollectionByNameOrId('faturas');

    const podeVer = "@request.auth.id != '' && empresa = @request.auth.empresa";
    const podeCriar =
      "@request.auth.id != '' && @request.body.empresa = @request.auth.empresa && @request.auth.papel != 'viewer'";
    const podeEscrever =
      "@request.auth.id != '' && empresa = @request.auth.empresa && @request.auth.papel != 'viewer'";
    const admin =
      "@request.auth.id != '' && empresa = @request.auth.empresa && (@request.auth.papel = 'owner' || @request.auth.papel = 'admin')";
    const mesma = (campo) =>
      `(@request.body.${campo}:isset = false || @request.body.${campo} = '' || @request.body.${campo}.empresa = @request.auth.empresa)`;

    const campoEmpresa = () => ({
      type: 'relation',
      name: 'empresa',
      required: true,
      maxSelect: 1,
      collectionId: empresas.id,
      cascadeDelete: true,
    });

    const li = new Collection({
      type: 'base',
      name: 'lotes_ingrediente',
      listRule: podeVer,
      viewRule: podeVer,
      createRule: `(${podeCriar}) && ${mesma('ingrediente')} && ${mesma('fatura')}`,
      updateRule: `(${podeEscrever}) && ${mesma('ingrediente')} && ${mesma('fatura')}`,
      deleteRule: podeEscrever,
      fields: [
        campoEmpresa(),
        { type: 'relation', name: 'ingrediente', required: true, maxSelect: 1, collectionId: ingredientes.id, cascadeDelete: true },
        { type: 'text', name: 'lote', required: true, max: 80 },
        { type: 'date', name: 'validade', required: false },
        { type: 'date', name: 'data_entrada', required: false },
        { type: 'text', name: 'fornecedor', required: false, max: 200 },
        { type: 'relation', name: 'fatura', required: false, maxSelect: 1, collectionId: faturas.id, cascadeDelete: false },
        { type: 'text', name: 'notas', required: false, max: 500 },
        { type: 'autodate', name: 'created', onCreate: true },
        { type: 'autodate', name: 'updated', onCreate: true, onUpdate: true },
      ],
      indexes: [
        'CREATE UNIQUE INDEX `idx_lotes_ingrediente_unico` ON `lotes_ingrediente` (`empresa`, `ingrediente`, `lote`)',
        'CREATE INDEX `idx_lotes_ingrediente_ing` ON `lotes_ingrediente` (`ingrediente`)',
      ],
    });
    app.save(li);

    const lp = new Collection({
      type: 'base',
      name: 'lotes_producao',
      listRule: podeVer,
      viewRule: podeVer,
      createRule: `(${podeCriar}) && ${mesma('ficha')}`,
      updateRule: `(${podeEscrever}) && ${mesma('ficha')}`,
      deleteRule: admin,
      fields: [
        campoEmpresa(),
        { type: 'text', name: 'codigo', required: true, max: 40 },
        { type: 'relation', name: 'ficha', required: false, maxSelect: 1, collectionId: fichas.id, cascadeDelete: false },
        { type: 'text', name: 'ficha_nome', required: false, max: 200 },
        { type: 'date', name: 'data_producao', required: true },
        { type: 'number', name: 'quantidade', required: false, min: 0 },
        { type: 'date', name: 'validade', required: false },
        // [{ ingrediente, nome, lote, validade, fornecedor }]
        { type: 'json', name: 'ingredientes', required: false, maxSize: 200000 },
        { type: 'text', name: 'responsavel', required: false, max: 120 },
        { type: 'text', name: 'notas', required: false, max: 500 },
        { type: 'autodate', name: 'created', onCreate: true },
        { type: 'autodate', name: 'updated', onCreate: true, onUpdate: true },
      ],
      indexes: [
        'CREATE UNIQUE INDEX `idx_lotes_producao_codigo` ON `lotes_producao` (`empresa`, `codigo`)',
        'CREATE INDEX `idx_lotes_producao_data` ON `lotes_producao` (`empresa`, `data_producao`)',
      ],
    });
    app.save(lp);
  },
  (app) => {
    for (const n of ['lotes_producao', 'lotes_ingrediente']) {
      try {
        app.delete(app.findCollectionByNameOrId(n));
      } catch (_) {}
    }
  },
);
