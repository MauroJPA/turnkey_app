/// <reference path="../pb_data/types.d.ts" />

// Financeiro (F-FIN-2) — custos fixos/variáveis reais da empresa (aluguel,
// salários, seguros, subscrições…), em valor mensal. Isto é diferente dos
// percentuais de `configuracoes_custo`, que só servem para sugerir o preço
// de venda a partir do custo de matéria-prima — aqui é o valor real que sai
// todos os meses, para o painel financeiro e o DRE (próximos marcos).

migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');

    // `~` no PocketBase é LIKE (substring), não regex — "papel ~
    // 'owner|admin'" nunca dava verdade (ver 1704672000_fix_config_rule.js).
    // A forma correta é o OR explícito.
    const ehOwnerOuAdmin =
      "(@request.auth.papel = 'owner' || @request.auth.papel = 'admin')";
    const podeVer = "@request.auth.id != '' && empresa = @request.auth.empresa";
    const podeEscrever =
      `@request.auth.id != '' && empresa = @request.auth.empresa && ${ehOwnerOuAdmin}`;
    const podeCriar =
      `@request.auth.id != '' && @request.body.empresa = @request.auth.empresa && ${ehOwnerOuAdmin}`;

    const custosFixos = new Collection({
      type: 'base',
      name: 'custos_fixos',
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
        { type: 'text', name: 'nome', required: true, max: 100 },
        {
          type: 'select',
          name: 'tipo',
          required: true,
          maxSelect: 1,
          values: ['fixo', 'variavel'],
        },
        { type: 'number', name: 'valor_mensal', required: true, min: 0 },
        // guarda o "arquivado" (não o "ativo") — o valor por omissão de um
        // campo bool é `false`, por isso um custo novo já fica ativo.
        { type: 'bool', name: 'arquivado', required: false },
        { type: 'text', name: 'notas', required: false, max: 300 },
        { type: 'autodate', name: 'created', onCreate: true },
        { type: 'autodate', name: 'updated', onCreate: true, onUpdate: true },
      ],
      indexes: [
        'CREATE INDEX `idx_custos_fixos_empresa` ON `custos_fixos` (`empresa`)',
      ],
    });
    app.save(custosFixos);
  },
  (app) => {
    app.delete(app.findCollectionByNameOrId('custos_fixos'));
  },
);
