/// <reference path="../pb_data/types.d.ts" />

// Financeiro (F-FIN-7) — equipamentos da loja (depreciação mensal) e dia de
// pagamento nos custos fixos.
//
// `equipamentos`: cada peça de equipamento (computador, forno, balcão…)
// com o custo de compra e a vida útil em anos — o custo mensal
// (depreciação) é `custo / (vida_util_anos * 12)`, calculado no cliente
// (não guardado, para nunca ficar desatualizado se o custo/vida útil
// mudar). O total entra no painel financeiro/DRE como despesa própria,
// separada dos custos fixos/variáveis.
//
// `custos_fixos.dia_pagamento`: dia do mês (1-31) em que o custo é pago —
// só para o lembrete "Pagamentos por vir" no Início, não afeta cálculos.

migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');

    const ehOwnerOuAdmin =
      "(@request.auth.papel = 'owner' || @request.auth.papel = 'admin')";
    const podeVer = "@request.auth.id != '' && empresa = @request.auth.empresa";
    const podeEscrever =
      `@request.auth.id != '' && empresa = @request.auth.empresa && ${ehOwnerOuAdmin}`;
    const podeCriar =
      `@request.auth.id != '' && @request.body.empresa = @request.auth.empresa && ${ehOwnerOuAdmin}`;

    const equipamentos = new Collection({
      type: 'base',
      name: 'equipamentos',
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
        { type: 'number', name: 'custo', required: true, min: 0 },
        { type: 'number', name: 'vida_util_anos', required: true, min: 0 },
        // guarda o "arquivado" (não o "ativo") — mesmo motivo de
        // `custos_fixos.arquivado`: o valor por omissão de um bool é
        // `false`, por isso um equipamento novo já fica ativo.
        { type: 'bool', name: 'arquivado', required: false },
        { type: 'text', name: 'notas', required: false, max: 300 },
        { type: 'autodate', name: 'created', onCreate: true },
        { type: 'autodate', name: 'updated', onCreate: true, onUpdate: true },
      ],
      indexes: [
        'CREATE INDEX `idx_equipamentos_empresa` ON `equipamentos` (`empresa`)',
      ],
    });
    app.save(equipamentos);

    const custosFixos = app.findCollectionByNameOrId('custos_fixos');
    if (!custosFixos.fields.getByName('dia_pagamento')) {
      custosFixos.fields.add(
        new Field({
          type: 'number',
          name: 'dia_pagamento',
          required: false,
          min: 1,
          max: 31,
        }),
      );
      app.save(custosFixos);
    }
  },
  (app) => {
    app.delete(app.findCollectionByNameOrId('equipamentos'));

    const custosFixos = app.findCollectionByNameOrId('custos_fixos');
    if (custosFixos.fields.getByName('dia_pagamento')) {
      custosFixos.fields.removeByName('dia_pagamento');
      app.save(custosFixos);
    }
  },
);
