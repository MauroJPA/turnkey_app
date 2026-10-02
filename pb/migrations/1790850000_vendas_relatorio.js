/// <reference path="../pb_data/types.d.ts" />

// Campos extra nas vendas, para o Relatório geral do Financeiro (ver
// "especificação de relatórios"): canal de venda, hora, método de pagamento e
// comissão, e — por linha — valor sem IVA, taxa de IVA e desconto. Todos
// opcionais: as vendas antigas ficam em branco (o relatório marca-as como
// "não indicado").
migrate(
  (app) => {
    const vendas = app.findCollectionByNameOrId('vendas');
    const novosVendas = [
      new Field({ type: 'text', name: 'canal', required: false, max: 60 }),
      new Field({ type: 'text', name: 'hora', required: false, max: 5 }),
      new Field({ type: 'text', name: 'metodo_pagamento', required: false, max: 60 }),
      new Field({ type: 'number', name: 'comissao', required: false }),
    ];
    for (const f of novosVendas) {
      if (!vendas.fields.getByName(f.name)) vendas.fields.add(f);
    }
    app.save(vendas);

    const itens = app.findCollectionByNameOrId('vendas_itens');
    const novosItens = [
      new Field({ type: 'number', name: 'valor_sem_iva', required: false }),
      new Field({ type: 'number', name: 'iva_percent', required: false }),
      new Field({ type: 'number', name: 'desconto', required: false }),
    ];
    for (const f of novosItens) {
      if (!itens.fields.getByName(f.name)) itens.fields.add(f);
    }
    app.save(itens);
  },
  (app) => {
    const vendas = app.findCollectionByNameOrId('vendas');
    for (const n of ['canal', 'hora', 'metodo_pagamento', 'comissao']) {
      if (vendas.fields.getByName(n)) vendas.fields.removeByName(n);
    }
    app.save(vendas);
    const itens = app.findCollectionByNameOrId('vendas_itens');
    for (const n of ['valor_sem_iva', 'iva_percent', 'desconto']) {
      if (itens.fields.getByName(n)) itens.fields.removeByName(n);
    }
    app.save(itens);
  },
);
