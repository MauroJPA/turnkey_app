/// <reference path="../pb_data/types.d.ts" />

// Email da contabilidade, configurável na app (Faturas → "Para a
// contabilidade") — antes só dava para definir por variável de ambiente no
// servidor (GC_TURNKEY_CONTAB_EMAIL), usada só pelo cron mensal.

migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');
    if (!empresas.fields.getByName('email_contabilidade')) {
      empresas.fields.add(
        new Field({
          type: 'email',
          name: 'email_contabilidade',
          required: false,
        }),
      );
    }
    app.save(empresas);
  },
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');
    empresas.fields.removeByName('email_contabilidade');
    app.save(empresas);
  },
);
