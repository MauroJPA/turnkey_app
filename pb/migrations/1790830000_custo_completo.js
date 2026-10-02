/// <reference path="../pb_data/types.d.ts" />

// `custo_completo` (bool) + `custo_sem_dados` (json, [{id, nome}]) em
// `receitas` e `fichas_tecnicas` — mesmo padrão já usado para `nutri.completo`
// /`nutri.sem_dados`, mas para o CUSTO: antes disto, uma linha "por ligar"
// (sem ingrediente nem sub_receita, ver itens_receita.nome_provisorio) ou um
// ingrediente sem preço diluíam o custo_por_grama silenciosamente — sem
// nenhum sinal de que o custo calculado estava incompleto/errado.
migrate(
  (app) => {
    for (const nome of ['receitas', 'fichas_tecnicas']) {
      const col = app.findCollectionByNameOrId(nome);
      if (!col.fields.getByName('custo_completo')) {
        col.fields.add(
          new Field({ type: 'bool', name: 'custo_completo', required: false }),
        );
      }
      if (!col.fields.getByName('custo_sem_dados')) {
        col.fields.add(
          new Field({
            type: 'json',
            name: 'custo_sem_dados',
            required: false,
            maxSize: 200000,
          }),
        );
      }
      app.save(col);
    }
  },
  (app) => {
    for (const nome of ['receitas', 'fichas_tecnicas']) {
      const col = app.findCollectionByNameOrId(nome);
      if (col.fields.getByName('custo_completo')) {
        col.fields.removeByName('custo_completo');
      }
      if (col.fields.getByName('custo_sem_dados')) {
        col.fields.removeByName('custo_sem_dados');
      }
      app.save(col);
    }
  },
);
