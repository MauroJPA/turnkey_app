/// <reference path="../pb_data/types.d.ts" />

// M0 — coleções base do turnkey_app.
// Escrito para a API JS de migrations do PocketBase v0.35.
// A validar contra o servidor real no M1 (ajustar se a API divergir).

migrate(
  (app) => {
    // ---- empresas -------------------------------------------------------
    const empresas = new Collection({
      type: 'base',
      name: 'empresas',
      listRule: "@request.auth.id != '' && id = @request.auth.empresa",
      viewRule: "@request.auth.id != '' && id = @request.auth.empresa",
      createRule: null, // criada no onboarding via regra de servidor / superuser
      updateRule:
        "@request.auth.id != '' && id = @request.auth.empresa && @request.auth.papel ~ 'owner'",
      deleteRule: null,
      fields: [
        { type: 'text', name: 'nome', required: true, max: 200 },
        { type: 'text', name: 'slug', required: true, presentable: true },
        {
          type: 'select',
          name: 'moeda',
          required: true,
          maxSelect: 1,
          values: ['EUR', 'BRL', 'USD', 'GBP'],
        },
        {
          type: 'select',
          name: 'regra_arredondamento',
          required: true,
          maxSelect: 1,
          values: ['cima', 'normal'],
        },
        { type: 'text', name: 'cor_marca', required: false, max: 9 },
        { type: 'file', name: 'logo', required: false, maxSelect: 1 },
        {
          type: 'select',
          name: 'plano',
          required: false,
          maxSelect: 1,
          values: ['free', 'pro'],
        },
      ],
      indexes: ['CREATE UNIQUE INDEX `idx_empresas_slug` ON `empresas` (`slug`)'],
    });
    app.save(empresas);

    // ---- users: + empresa, + papel, + nome -----------------------------
    const users = app.findCollectionByNameOrId('users');
    users.fields.add(
      new Field({
        type: 'text',
        name: 'nome',
        required: false,
        max: 200,
      }),
    );
    users.fields.add(
      new Field({
        type: 'relation',
        name: 'empresa',
        required: false, // nulo até completar o onboarding
        maxSelect: 1,
        collectionId: empresas.id,
        cascadeDelete: false,
      }),
    );
    users.fields.add(
      new Field({
        type: 'select',
        name: 'papel',
        required: false,
        maxSelect: 1,
        values: ['owner', 'admin', 'editor', 'viewer'],
      }),
    );
    app.save(users);

    // ---- configuracoes_custo (1 por empresa) ---------------------------
    const configs = new Collection({
      type: 'base',
      name: 'configuracoes_custo',
      listRule: "@request.auth.id != '' && empresa = @request.auth.empresa",
      viewRule: "@request.auth.id != '' && empresa = @request.auth.empresa",
      createRule:
        "@request.auth.id != '' && @request.body.empresa = @request.auth.empresa",
      updateRule:
        "@request.auth.id != '' && empresa = @request.auth.empresa && @request.auth.papel ~ 'owner|admin'",
      deleteRule: null,
      fields: [
        {
          type: 'relation',
          name: 'empresa',
          required: true,
          maxSelect: 1,
          collectionId: empresas.id,
          cascadeDelete: true,
        },
        { type: 'number', name: 'salario', required: false },
        { type: 'number', name: 'aluguel', required: false },
        { type: 'number', name: 'impostos', required: false },
        {
          type: 'number',
          name: 'servicos_e_gastos_intangiveis',
          required: false,
        },
        { type: 'number', name: 'despesas_fixas', required: false },
        { type: 'number', name: 'taxas_financeiras', required: false },
        { type: 'number', name: 'margem_de_lucro', required: false },
      ],
      indexes: [
        'CREATE UNIQUE INDEX `idx_configs_empresa` ON `configuracoes_custo` (`empresa`)',
      ],
    });
    app.save(configs);
  },
  (app) => {
    // rollback
    const users = app.findCollectionByNameOrId('users');
    users.fields.removeByName('nome');
    users.fields.removeByName('empresa');
    users.fields.removeByName('papel');
    app.save(users);

    app.delete(app.findCollectionByNameOrId('configuracoes_custo'));
    app.delete(app.findCollectionByNameOrId('empresas'));
  },
);
