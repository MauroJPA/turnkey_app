/// <reference path="../pb_data/types.d.ts" />

// `fichas_tecnicas.nomes_venda`: descrições de linhas de venda (Vendus/CSV)
// já ligadas manualmente a este produto (ver /api/gc_turnkey/vendas/ligar-produto
// e match_ficha.dart#fichaParaVenda) — mesmo padrão de "nomes_fatura" já usado
// em ingrediente_produtos/consumiveis/embalagens para faturas.
//
// Índice (empresa, descricao) em vendas_itens: a atualização em massa ao
// ligar um produto filtra exatamente por estes dois campos.
migrate(
  (app) => {
    const fichas = app.findCollectionByNameOrId('fichas_tecnicas');
    if (!fichas.fields.getByName('nomes_venda')) {
      fichas.fields.add(
        new Field({
          type: 'json',
          name: 'nomes_venda',
          required: false,
          maxSize: 20000,
        }),
      );
      app.save(fichas);
    }

    const itens = app.findCollectionByNameOrId('vendas_itens');
    const temIndice = itens.indexes.some((i) =>
      i.includes('idx_vendas_itens_empresa_descricao'),
    );
    if (!temIndice) {
      itens.indexes = itens.indexes.concat([
        'CREATE INDEX `idx_vendas_itens_empresa_descricao` ON `vendas_itens` (`empresa`, `descricao`)',
      ]);
      app.save(itens);
    }
  },
  (app) => {
    const fichas = app.findCollectionByNameOrId('fichas_tecnicas');
    if (fichas.fields.getByName('nomes_venda')) {
      fichas.fields.removeByName('nomes_venda');
      app.save(fichas);
    }

    const itens = app.findCollectionByNameOrId('vendas_itens');
    itens.indexes = itens.indexes.filter(
      (i) => !i.includes('idx_vendas_itens_empresa_descricao'),
    );
    app.save(itens);
  },
);
