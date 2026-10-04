/// <reference path="../pb_data/types.d.ts" />

// Segurança alimentar (HACCP): controlos periódicos e os seus registos.
//
// `haccp_controlos` — o que é preciso controlar: temperatura de frigoríficos/
// arcas (com limites), limpezas, controlo de pragas, manutenção/validades
// (extintor, desinfestação, análises) ou outros. Cada um tem a sua
// periodicidade (em dias; 0 = ocasional) e, nos diários, quantas vezes por dia.
// `haccp_registos` — cada vez que o controlo foi feito (ou que houve uma
// ocorrência): valor medido, se esteve conforme, quem fez, ação corretiva e,
// em manutenções, a próxima validade. Não se apagam (histórico para auditoria):
// só o proprietário/administrador o pode fazer.
//
// Também: `custos_fixos.categoria` (texto livre com sugestões), para separar
// p.ex. "Controlo operacional" (HACCP, pragas, extintores) dos outros custos.

migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');
    const users = app.findCollectionByNameOrId('users');

    const ehOwnerOuAdmin =
      "(@request.auth.papel = 'owner' || @request.auth.papel = 'admin')";
    const podeVer = "@request.auth.id != '' && empresa = @request.auth.empresa";
    const podeEscrever =
      "@request.auth.id != '' && empresa = @request.auth.empresa && @request.auth.papel != 'viewer'";
    const podeCriar =
      "@request.auth.id != '' && @request.body.empresa = @request.auth.empresa && @request.auth.papel != 'viewer'";
    const podeApagar = `@request.auth.id != '' && empresa = @request.auth.empresa && ${ehOwnerOuAdmin}`;
    const mesmaEmpresa = (campo) =>
      `(@request.body.${campo}:isset = false || @request.body.${campo} = '' || @request.body.${campo}.empresa = @request.auth.empresa)`;

    const campoEmpresa = () => ({
      type: 'relation',
      name: 'empresa',
      required: true,
      maxSelect: 1,
      collectionId: empresas.id,
      cascadeDelete: true,
    });

    // --- haccp_controlos ------------------------------------------------------
    const controlos = new Collection({
      type: 'base',
      name: 'haccp_controlos',
      listRule: podeVer,
      viewRule: podeVer,
      createRule: podeCriar,
      updateRule: podeEscrever,
      deleteRule: podeApagar,
      fields: [
        campoEmpresa(),
        { type: 'text', name: 'nome', required: true, max: 100 },
        {
          type: 'select',
          name: 'tipo',
          required: true,
          maxSelect: 1,
          values: ['temperatura', 'limpeza', 'praga', 'manutencao', 'outro'],
        },
        // 0 = sem periodicidade (ocasional)
        { type: 'number', name: 'periodicidade_dias', required: false, min: 0 },
        // só nos diários (periodicidade 1): quantos registos por dia
        { type: 'number', name: 'vezes_por_dia', required: false, min: 0 },
        // só nas temperaturas
        // um número por preencher chega como 0, por isso há flags a dizer se o
        // limite existe (0 °C é um limite válido; -18 sem mínimo também)
        { type: 'bool', name: 'usa_limite_min', required: false },
        { type: 'number', name: 'limite_min', required: false },
        { type: 'bool', name: 'usa_limite_max', required: false },
        { type: 'number', name: 'limite_max', required: false },
        { type: 'text', name: 'unidade', required: false, max: 10 },
        { type: 'text', name: 'local', required: false, max: 100 },
        { type: 'text', name: 'instrucoes', required: false, max: 500 },
        { type: 'number', name: 'ordem', required: false },
        { type: 'bool', name: 'arquivado', required: false },
        { type: 'autodate', name: 'created', onCreate: true },
        { type: 'autodate', name: 'updated', onCreate: true, onUpdate: true },
      ],
      indexes: [
        'CREATE INDEX `idx_haccp_controlos_empresa` ON `haccp_controlos` (`empresa`)',
      ],
    });
    app.save(controlos);

    // --- haccp_registos ---------------------------------------------------------
    const registos = new Collection({
      type: 'base',
      name: 'haccp_registos',
      listRule: podeVer,
      viewRule: podeVer,
      createRule: `(${podeCriar}) && ${mesmaEmpresa('controlo')}`,
      updateRule: `(${podeEscrever}) && ${mesmaEmpresa('controlo')}`,
      deleteRule: podeApagar,
      fields: [
        campoEmpresa(),
        {
          type: 'relation',
          name: 'controlo',
          required: true,
          maxSelect: 1,
          collectionId: controlos.id,
          cascadeDelete: true,
        },
        { type: 'date', name: 'data_hora', required: true },
        // temperatura medida (ou outro valor)
        { type: 'number', name: 'valor', required: false },
        { type: 'bool', name: 'conforme', required: false },
        { type: 'text', name: 'responsavel', required: false, max: 80 },
        { type: 'text', name: 'notas', required: false, max: 500 },
        { type: 'text', name: 'acao_corretiva', required: false, max: 500 },
        // uma não conformidade já tratada
        { type: 'bool', name: 'resolvido', required: false },
        // manutenções/validades: quando vence a seguir
        { type: 'date', name: 'proximo_vencimento', required: false },
        {
          type: 'relation',
          name: 'autor',
          required: false,
          maxSelect: 1,
          collectionId: users.id,
          cascadeDelete: false,
        },
        { type: 'autodate', name: 'created', onCreate: true },
        { type: 'autodate', name: 'updated', onCreate: true, onUpdate: true },
      ],
      indexes: [
        'CREATE INDEX `idx_haccp_registos_controlo_data` ON `haccp_registos` (`controlo`, `data_hora`)',
        'CREATE INDEX `idx_haccp_registos_empresa_data` ON `haccp_registos` (`empresa`, `data_hora`)',
      ],
    });
    app.save(registos);

    // --- custos_fixos.categoria -------------------------------------------------
    const custos = app.findCollectionByNameOrId('custos_fixos');
    if (!custos.fields.getByName('categoria')) {
      custos.fields.add(
        new Field({ type: 'text', name: 'categoria', required: false, max: 60 }),
      );
      app.save(custos);
    }
  },
  (app) => {
    const custos = app.findCollectionByNameOrId('custos_fixos');
    if (custos.fields.getByName('categoria')) {
      custos.fields.removeByName('categoria');
      app.save(custos);
    }
    app.delete(app.findCollectionByNameOrId('haccp_registos'));
    app.delete(app.findCollectionByNameOrId('haccp_controlos'));
  },
);
