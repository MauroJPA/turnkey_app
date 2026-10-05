/// <reference path="../pb_data/types.d.ts" />

// `configuracoes_custo.cmv`: o CMV (custo da matéria-prima, % do preço sem IVA)
// passa a ser definido diretamente; a margem de lucro é o que sobra
// (100 − CMV − rubricas de custo). Os campos `impostos` e `margem_de_lucro`
// deixam de ser usados (o IVA soma-se no fim; ficam na base, sem uso).
// Para as empresas existentes o CMV fica igual ao que já era (100 menos a
// soma de todas as rubricas de então), por isso o preço sugerido não muda.
migrate(
  (app) => {
    const c = app.findCollectionByNameOrId('configuracoes_custo');
    if (!c.fields.getByName('cmv')) {
      c.fields.add(
        new Field({ type: 'number', name: 'cmv', required: false, min: 0, max: 100 }),
      );
      app.save(c);
    }
    const registos = app.findAllRecords('configuracoes_custo');
    for (const r of registos) {
      if ((r.getFloat('cmv') || 0) > 0) continue;
      const soma =
        r.getFloat('salario') +
        r.getFloat('aluguel') +
        r.getFloat('impostos') +
        r.getFloat('servicos_e_gastos_intangiveis') +
        r.getFloat('despesas_fixas') +
        r.getFloat('taxas_financeiras') +
        r.getFloat('margem_de_lucro');
      let cmv = 100 - soma;
      if (!(cmv > 0)) cmv = 100;
      if (cmv > 100) cmv = 100;
      r.set('cmv', cmv);
      app.save(r);
    }
  },
  (app) => {
    const c = app.findCollectionByNameOrId('configuracoes_custo');
    if (c.fields.getByName('cmv')) {
      c.fields.removeByName('cmv');
      app.save(c);
    }
  },
);
