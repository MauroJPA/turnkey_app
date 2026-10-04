/// <reference path="../pb_data/types.d.ts" />

// `configuracoes_custo.iva_vendas`: taxa de IVA das vendas (%), usada para
// estimar o IVA a entregar quando uma venda não traz o valor sem IVA
// (Painel financeiro → "IVA a separar"). 0 = não definida.
migrate(
  (app) => {
    const c = app.findCollectionByNameOrId('configuracoes_custo');
    if (!c.fields.getByName('iva_vendas')) {
      c.fields.add(
        new Field({ type: 'number', name: 'iva_vendas', required: false, min: 0, max: 100 }),
      );
      app.save(c);
    }
  },
  (app) => {
    const c = app.findCollectionByNameOrId('configuracoes_custo');
    if (c.fields.getByName('iva_vendas')) {
      c.fields.removeByName('iva_vendas');
      app.save(c);
    }
  },
);
