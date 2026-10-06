/// <reference path="../pb_data/types.d.ts" />
// Dias de trabalho da empresa (1.91.0): `configuracoes_custo.dias_trabalho` guarda os
// dias da semana em que se trabalha (1 = segunda … 7 = domingo), ex. "1,2,3,4,5,6".
// Vazio = todos os dias. Usa-se no "Quantos assar" (não prevê dias de folga).
migrate(
  (app) => {
    const cfg = app.findCollectionByNameOrId('configuracoes_custo');
    if (!cfg.fields.getByName('dias_trabalho')) {
      cfg.fields.add(new Field({ type: 'text', name: 'dias_trabalho', required: false, max: 20 }));
      app.save(cfg);
    }
  },
  (app) => {
    const cfg = app.findCollectionByNameOrId('configuracoes_custo');
    if (cfg.fields.getByName('dias_trabalho')) {
      cfg.fields.removeByName('dias_trabalho');
      app.save(cfg);
    }
  },
);
