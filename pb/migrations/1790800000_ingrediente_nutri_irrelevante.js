/// <reference path="../pb_data/types.d.ts" />

// Marca um ingrediente (ex.: corante, aroma) como "sem valor nutricional
// relevante" — usado em quantidade residual, cujo contributo deve ser
// tratado como zero confirmado em vez de dados em falta na declaração
// nutricional das receitas/fichas (ver cascade.js).
migrate(
  (app) => {
    const ing = app.findCollectionByNameOrId('ingredientes');
    if (!ing.fields.getByName('nutri_irrelevante')) {
      ing.fields.add(
        new Field({
          type: 'bool',
          name: 'nutri_irrelevante',
          required: false,
        }),
      );
      app.save(ing);
    }
  },
  (app) => {
    const ing = app.findCollectionByNameOrId('ingredientes');
    if (ing.fields.getByName('nutri_irrelevante')) {
      ing.fields.removeByName('nutri_irrelevante');
      app.save(ing);
    }
  },
);
