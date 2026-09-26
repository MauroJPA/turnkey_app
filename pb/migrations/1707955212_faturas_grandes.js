/// <reference path="../pb_data/types.d.ts" />

// Faturas grandes: um PDF digitalizado no telemóvel com dezenas de páginas pode ter
// 80 MB ou mais (o limite antigo, 8 MB, dava "Request entity too large").
// `ficheiro` passa a aceitar até 200 MB, e `dados_ia` a guardar o progresso da análise
// por janelas de páginas (até 5 MB).

migrate(
  (app) => {
    const faturas = app.findCollectionByNameOrId('faturas');
    faturas.fields.getByName('ficheiro').maxSize = 200 * 1024 * 1024;
    faturas.fields.getByName('dados_ia').maxSize = 5 * 1024 * 1024;
    app.save(faturas);
  },
  (app) => {
    const faturas = app.findCollectionByNameOrId('faturas');
    faturas.fields.getByName('ficheiro').maxSize = 8388608;
    faturas.fields.getByName('dados_ia').maxSize = 200000;
    app.save(faturas);
  },
);
