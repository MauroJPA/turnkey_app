/// <reference path="../pb_data/types.d.ts" />

// Faturas → Equipamentos. Uma linha de fatura pode ser um equipamento (forno,
// batedeira, balcão, computador…): ao aplicar, cria-se o registo em
// `equipamentos` (entra na depreciação mensal e nos custos da empresa).
// `faturas_itens.equipamento` guarda qual foi criado, para a linha aparecer
// como já aplicada ao reabrir a fatura.

migrate(
  (app) => {
    const itens = app.findCollectionByNameOrId('faturas_itens');
    if (!itens.fields.getByName('equipamento')) {
      const equipamentos = app.findCollectionByNameOrId('equipamentos');
      itens.fields.add(
        new Field({
          type: 'relation',
          name: 'equipamento',
          required: false,
          maxSelect: 1,
          collectionId: equipamentos.id,
          // apagar o equipamento não apaga a linha da fatura
          cascadeDelete: false,
        }),
      );
      app.save(itens);
    }
  },
  (app) => {
    const itens = app.findCollectionByNameOrId('faturas_itens');
    itens.fields.removeByName('equipamento');
    app.save(itens);
  },
);
