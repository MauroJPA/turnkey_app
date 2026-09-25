/// <reference path="../pb_data/types.d.ts" />

// Alergénios (e vestígios) por produto de compra. Ao contrário dos do
// ingrediente genérico, contam SÓ quando uma receita fixa esse produto: são
// acrescentados aos do genérico (nunca os substituem). Ex.: "Chocolate X" leva
// "pode conter frutos de casca rija" — só aparece nos produtos cujas receitas
// fixam essa marca.

migrate(
  (app) => {
    const ing = app.findCollectionByNameOrId('ingredientes');
    const valores = ing.fields.getByName('alergenios').values;
    const produtos = app.findCollectionByNameOrId('ingrediente_produtos');
    for (const nome of ['alergenios', 'alergenios_tracos']) {
      if (produtos.fields.getByName(nome)) continue;
      produtos.fields.add(
        new Field({
          type: 'select',
          name: nome,
          required: false,
          maxSelect: valores.length,
          values: valores,
        }),
      );
    }
    app.save(produtos);
  },
  (app) => {
    const produtos = app.findCollectionByNameOrId('ingrediente_produtos');
    produtos.fields.removeByName('alergenios');
    produtos.fields.removeByName('alergenios_tracos');
    app.save(produtos);
  },
);
