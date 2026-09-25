/// <reference path="../pb_data/types.d.ts" />

// Unidade de medida do ingrediente: g (por omissão), ml ou un. Todas as
// quantidades DESSE ingrediente (linhas de receita, embalagem, stock, compras)
// ficam nessa unidade — os campos continuam a chamar-se `*_g` por razões
// históricas. Para pesos (rendimento da receita, nutrição, rótulo) converte-se
// para gramas: ml × densidade (`nutri_densidade`, 1 por omissão) e
// un × `gramas_unidade` (peso de cada unidade).

migrate(
  (app) => {
    const ing = app.findCollectionByNameOrId('ingredientes');
    if (!ing.fields.getByName('unidade')) {
      ing.fields.add(
        new Field({
          type: 'select',
          name: 'unidade',
          required: false,
          maxSelect: 1,
          values: ['g', 'ml', 'un'],
        }),
      );
    }
    if (!ing.fields.getByName('gramas_unidade')) {
      ing.fields.add(new Field({ type: 'number', name: 'gramas_unidade', required: false, min: 0 }));
    }
    app.save(ing);
  },
  (app) => {
    const ing = app.findCollectionByNameOrId('ingredientes');
    ing.fields.removeByName('unidade');
    ing.fields.removeByName('gramas_unidade');
    app.save(ing);
  },
);
