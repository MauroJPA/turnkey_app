/// <reference path="../pb_data/types.d.ts" />

// Nutrição própria de um produto de compra. Quando `nutri_propria` está ligado e
// uma receita FIXA esse produto, a receita usa os valores do produto (por 100 g
// ou 100 ml) em vez dos do ingrediente genérico. Sem produto fixado, ou com
// `nutri_propria` desligado, contam sempre os do ingrediente.

migrate(
  (app) => {
    const produtos = app.findCollectionByNameOrId('ingrediente_produtos');
    const adicionar = (campo) => {
      if (!produtos.fields.getByName(campo.name)) produtos.fields.add(new Field(campo));
    };
    adicionar({ type: 'bool', name: 'nutri_propria', required: false });
    for (const nome of [
      'nutri_energia_kcal',
      'nutri_lipidos_g',
      'nutri_saturados_g',
      'nutri_hidratos_g',
      'nutri_acucares_g',
      'nutri_fibra_g',
      'nutri_proteina_g',
      'nutri_sal_g',
      'nutri_densidade',
    ]) {
      adicionar({ type: 'number', name: nome, required: false, min: 0 });
    }
    adicionar({
      type: 'select',
      name: 'nutri_base',
      required: false,
      maxSelect: 1,
      values: ['100g', '100ml'],
    });
    app.save(produtos);
  },
  (app) => {
    const produtos = app.findCollectionByNameOrId('ingrediente_produtos');
    for (const nome of [
      'nutri_propria',
      'nutri_energia_kcal',
      'nutri_lipidos_g',
      'nutri_saturados_g',
      'nutri_hidratos_g',
      'nutri_acucares_g',
      'nutri_fibra_g',
      'nutri_proteina_g',
      'nutri_sal_g',
      'nutri_densidade',
      'nutri_base',
    ]) {
      produtos.fields.removeByName(nome);
    }
    app.save(produtos);
  },
);
