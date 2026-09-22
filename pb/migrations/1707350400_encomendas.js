/// <reference path="../pb_data/types.d.ts" />

// Encomendas (E-1) — clientes encomendam produtos para uma data/hora
// específica; a fábrica vê a lista na app (tablet) ou imprime o talão.
//
// `encomendas` — uma encomenda (cliente, data/hora, estado, valor total e
// quanto já foi pago — o estado do pagamento, ex. "parcial", é derivado
// destes dois no cliente, não guardado).
// `encomendas_itens` — as linhas (ficha técnica + quantidade).
// `configuracoes_encomendas` — 1 linha por empresa: tamanho do talão,
// impressão automática ao criar, e horas de antecedência do lembrete
// "Encomendas por vir" no Início. Sem linha criada, a app usa valores por
// omissão (não é preciso criar isto no onboarding).

migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');
    const fichas = app.findCollectionByNameOrId('fichas_tecnicas');
    const users = app.findCollectionByNameOrId('users');

    const ehOwnerOuAdmin =
      "(@request.auth.papel = 'owner' || @request.auth.papel = 'admin')";
    const podeVer = "@request.auth.id != '' && empresa = @request.auth.empresa";
    const podeEscrever =
      "@request.auth.id != '' && empresa = @request.auth.empresa && @request.auth.papel != 'viewer'";
    const podeCriar =
      "@request.auth.id != '' && @request.body.empresa = @request.auth.empresa && @request.auth.papel != 'viewer'";
    const podeEscreverConfig =
      `@request.auth.id != '' && empresa = @request.auth.empresa && ${ehOwnerOuAdmin}`;
    const podeCriarConfig =
      `@request.auth.id != '' && @request.body.empresa = @request.auth.empresa && ${ehOwnerOuAdmin}`;

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

    // --- encomendas --------------------------------------------------------
    const encomendas = new Collection({
      type: 'base',
      name: 'encomendas',
      listRule: podeVer,
      viewRule: podeVer,
      createRule: podeCriar,
      updateRule: podeEscrever,
      deleteRule: podeEscrever,
      fields: [
        campoEmpresa(),
        { type: 'text', name: 'cliente_nome', required: true, max: 120 },
        { type: 'text', name: 'cliente_telefone', required: false, max: 30 },
        { type: 'text', name: 'cliente_notas', required: false, max: 300 },
        { type: 'date', name: 'data_hora', required: true },
        {
          type: 'select',
          name: 'estado',
          required: true,
          maxSelect: 1,
          values: ['nova', 'em_producao', 'pronta', 'entregue', 'cancelada'],
        },
        { type: 'text', name: 'notas', required: false, max: 500 },
        // 0 = sem valor informado (mesmo motivo de outros campos "money"
        // opcionais nesta app) — a app sugere o valor a partir do preço de
        // venda das fichas, mas fica sempre editável ou vazio.
        { type: 'number', name: 'valor_total', required: false, min: 0 },
        { type: 'number', name: 'valor_pago', required: false, min: 0 },
        {
          type: 'relation',
          name: 'criado_por',
          required: false,
          maxSelect: 1,
          collectionId: users.id,
          cascadeDelete: false,
        },
      ],
      indexes: [
        'CREATE INDEX `idx_encomendas_empresa_data` ON `encomendas` (`empresa`, `data_hora`)',
      ],
    });
    addCreated(encomendas);
    addUpdated(encomendas);
    app.save(encomendas);

    // --- encomendas_itens ----------------------------------------------
    const encomendasItens = new Collection({
      type: 'base',
      name: 'encomendas_itens',
      listRule: podeVer,
      viewRule: podeVer,
      createRule: podeCriar,
      updateRule: podeEscrever,
      deleteRule: podeEscrever,
      fields: [
        campoEmpresa(),
        {
          type: 'relation',
          name: 'encomenda',
          required: true,
          maxSelect: 1,
          collectionId: encomendas.id,
          cascadeDelete: true,
        },
        {
          type: 'relation',
          name: 'ficha',
          required: true,
          maxSelect: 1,
          collectionId: fichas.id,
          cascadeDelete: false,
        },
        { type: 'number', name: 'quantidade', required: true, min: 0 },
        { type: 'text', name: 'notas', required: false, max: 200 },
      ],
      indexes: [
        'CREATE INDEX `idx_encomendas_itens_encomenda` ON `encomendas_itens` (`encomenda`)',
      ],
    });
    addCreated(encomendasItens);
    app.save(encomendasItens);

    // --- configuracoes_encomendas ---------------------------------------
    const configEncomendas = new Collection({
      type: 'base',
      name: 'configuracoes_encomendas',
      listRule: podeVer,
      viewRule: podeVer,
      createRule: podeCriarConfig,
      updateRule: podeEscreverConfig,
      deleteRule: podeEscreverConfig,
      fields: [
        campoEmpresa(),
        {
          type: 'select',
          name: 'talao_tamanho',
          required: false,
          maxSelect: 1,
          values: ['termico80', 'a4'],
        },
        { type: 'bool', name: 'imprimir_auto', required: false },
        { type: 'number', name: 'lembrete_horas', required: false, min: 0 },
      ],
      indexes: [
        'CREATE UNIQUE INDEX `idx_config_encomendas_empresa` ON `configuracoes_encomendas` (`empresa`)',
      ],
    });
    app.save(configEncomendas);

    // --- historico: nova entidade "encomenda" ---------------------------
    const historico = app.findCollectionByNameOrId('historico');
    const entidadeTipo = historico.fields.getByName('entidade_tipo');
    if (entidadeTipo && !entidadeTipo.values.includes('encomenda')) {
      entidadeTipo.values = entidadeTipo.values.concat(['encomenda']);
      app.save(historico);
    }
  },
  (app) => {
    app.delete(app.findCollectionByNameOrId('configuracoes_encomendas'));
    app.delete(app.findCollectionByNameOrId('encomendas_itens'));
    app.delete(app.findCollectionByNameOrId('encomendas'));
  },
);
