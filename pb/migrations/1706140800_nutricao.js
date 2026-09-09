/// <reference path="../pb_data/types.d.ts" />

// Nutrição e alergénios.
//
// - `ingredientes`: valores nutricionais por 100 g/ml + os 14 alergénios da UE
//   (Reg. 1169/2011). Origem e data de atualização.
// - `receitas` / `fichas_tecnicas`: cache `nutri` (JSON) calculado em cascata,
//   + `perda_cozedura_pct` na receita (a água que sai a cozer concentra os
//   valores por 100 g de produto acabado).
// - `ingredientes_referencia`: tabela partilhada (INSA TCA) para pré-preencher.

migrate(
  (app) => {
    const ALERGENIOS = [
      'Glúten', 'Crustáceos', 'Ovos', 'Peixe', 'Amendoins', 'Soja', 'Leite',
      'Frutos de casca rija', 'Aipo', 'Mostarda', 'Sésamo', 'Sulfitos',
      'Tremoço', 'Moluscos',
    ];
    const NUTRI_NUM = [
      'nutri_energia_kcal', 'nutri_lipidos_g', 'nutri_saturados_g',
      'nutri_hidratos_g', 'nutri_acucares_g', 'nutri_fibra_g',
      'nutri_proteina_g', 'nutri_sal_g',
    ];

    // --- ingredientes -------------------------------------------------
    const ing = app.findCollectionByNameOrId('ingredientes');
    for (const nome of NUTRI_NUM) {
      if (!ing.fields.getByName(nome)) {
        ing.fields.add(
          new Field({ type: 'number', name: nome, required: false, min: 0 }),
        );
      }
    }
    if (!ing.fields.getByName('nutri_base')) {
      ing.fields.add(
        new Field({
          type: 'select',
          name: 'nutri_base',
          required: false,
          maxSelect: 1,
          values: ['100g', '100ml'],
        }),
      );
    }
    if (!ing.fields.getByName('nutri_densidade')) {
      ing.fields.add(
        new Field({
          type: 'number',
          name: 'nutri_densidade',
          required: false,
          min: 0,
        }),
      );
    }
    if (!ing.fields.getByName('nutri_origem')) {
      ing.fields.add(
        new Field({ type: 'text', name: 'nutri_origem', required: false, max: 40 }),
      );
    }
    if (!ing.fields.getByName('nutri_atualizado_em')) {
      ing.fields.add(
        new Field({ type: 'date', name: 'nutri_atualizado_em', required: false }),
      );
    }
    if (!ing.fields.getByName('alergenios')) {
      ing.fields.add(
        new Field({
          type: 'select',
          name: 'alergenios',
          required: false,
          maxSelect: ALERGENIOS.length,
          values: ALERGENIOS,
        }),
      );
    }
    if (!ing.fields.getByName('alergenios_tracos')) {
      ing.fields.add(
        new Field({
          type: 'select',
          name: 'alergenios_tracos',
          required: false,
          maxSelect: ALERGENIOS.length,
          values: ALERGENIOS,
        }),
      );
    }
    app.save(ing);

    // --- receitas ---------------------------------------------------
    const rec = app.findCollectionByNameOrId('receitas');
    if (!rec.fields.getByName('perda_cozedura_pct')) {
      rec.fields.add(
        new Field({
          type: 'number',
          name: 'perda_cozedura_pct',
          required: false,
          min: 0,
          max: 95,
        }),
      );
    }
    if (!rec.fields.getByName('nutri')) {
      rec.fields.add(
        new Field({ type: 'json', name: 'nutri', required: false, maxSize: 6000 }),
      );
    }
    app.save(rec);

    // --- fichas_tecnicas -----------------------------------------
    const fic = app.findCollectionByNameOrId('fichas_tecnicas');
    if (!fic.fields.getByName('nutri')) {
      fic.fields.add(
        new Field({ type: 'json', name: 'nutri', required: false, maxSize: 6000 }),
      );
    }
    app.save(fic);

    // --- ingredientes_referencia (tabela partilhada, ex.: INSA TCA) ---
    let ref;
    try {
      ref = app.findCollectionByNameOrId('ingredientes_referencia');
    } catch (_) {
      ref = null;
    }
    if (!ref) {
      const nova = new Collection({
        type: 'base',
        name: 'ingredientes_referencia',
        // qualquer utilizador autenticado lê; só o superuser/importador escreve
        listRule: "@request.auth.id != ''",
        viewRule: "@request.auth.id != ''",
        createRule: null,
        updateRule: null,
        deleteRule: null,
        fields: [
          { type: 'text', name: 'codigo', required: false, max: 40 },
          { type: 'text', name: 'nome', required: true, max: 200 },
          { type: 'text', name: 'grupo', required: false, max: 120 },
          { type: 'number', name: 'nutri_energia_kcal', required: false, min: 0 },
          { type: 'number', name: 'nutri_lipidos_g', required: false, min: 0 },
          { type: 'number', name: 'nutri_saturados_g', required: false, min: 0 },
          { type: 'number', name: 'nutri_hidratos_g', required: false, min: 0 },
          { type: 'number', name: 'nutri_acucares_g', required: false, min: 0 },
          { type: 'number', name: 'nutri_fibra_g', required: false, min: 0 },
          { type: 'number', name: 'nutri_proteina_g', required: false, min: 0 },
          { type: 'number', name: 'nutri_sal_g', required: false, min: 0 },
          { type: 'text', name: 'fonte', required: false, max: 120 },
          { type: 'text', name: 'sinonimos', required: false, max: 300 },
        ],
        indexes: [
          'CREATE INDEX `idx_ref_nome` ON `ingredientes_referencia` (`nome`)',
        ],
      });
      nova.fields.add(
        new Field({ type: 'autodate', name: 'created', onCreate: true }),
      );
      app.save(nova);
    }
  },
  (app) => {
    const NUTRI_NUM = [
      'nutri_energia_kcal', 'nutri_lipidos_g', 'nutri_saturados_g',
      'nutri_hidratos_g', 'nutri_acucares_g', 'nutri_fibra_g',
      'nutri_proteina_g', 'nutri_sal_g',
    ];
    try {
      app.delete(app.findCollectionByNameOrId('ingredientes_referencia'));
    } catch (_) {}

    const ing = app.findCollectionByNameOrId('ingredientes');
    for (const nome of NUTRI_NUM.concat([
      'nutri_base', 'nutri_densidade', 'nutri_origem', 'nutri_atualizado_em',
      'alergenios', 'alergenios_tracos',
    ])) {
      ing.fields.removeByName(nome);
    }
    app.save(ing);

    const rec = app.findCollectionByNameOrId('receitas');
    rec.fields.removeByName('perda_cozedura_pct');
    rec.fields.removeByName('nutri');
    app.save(rec);

    const fic = app.findCollectionByNameOrId('fichas_tecnicas');
    fic.fields.removeByName('nutri');
    app.save(fic);
  },
);
