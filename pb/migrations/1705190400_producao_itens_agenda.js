/// <reference path="../pb_data/types.d.ts" />

// Fase 3 — campos de agenda em `producao_itens`:
// formato de cookie, recheio, prioridade, hora limite e unidades previstas.

migrate(
  (app) => {
    const itens = app.findCollectionByNameOrId('producao_itens');
    const formatos = app.findCollectionByNameOrId('formatos_cookie');
    const receitas = app.findCollectionByNameOrId('receitas');

    if (!itens.fields.getByName('formato')) {
      itens.fields.add(
        new Field({
          type: 'relation',
          name: 'formato',
          required: false,
          maxSelect: 1,
          collectionId: formatos.id,
          cascadeDelete: false,
        }),
      );
    }
    if (!itens.fields.getByName('recheio')) {
      itens.fields.add(
        new Field({
          type: 'relation',
          name: 'recheio',
          required: false,
          maxSelect: 1,
          collectionId: receitas.id,
          cascadeDelete: false,
        }),
      );
    }
    if (!itens.fields.getByName('prioridade')) {
      itens.fields.add(
        new Field({
          type: 'select',
          name: 'prioridade',
          required: false,
          maxSelect: 1,
          values: ['alta', 'media', 'baixa'],
        }),
      );
    }
    if (!itens.fields.getByName('hora_limite')) {
      itens.fields.add(
        new Field({ type: 'text', name: 'hora_limite', required: false, max: 5 }),
      );
    }
    if (!itens.fields.getByName('unidades_previstas')) {
      itens.fields.add(
        new Field({
          type: 'number',
          name: 'unidades_previstas',
          required: false,
          min: 0,
        }),
      );
    }
    app.save(itens);
  },
  (app) => {
    const itens = app.findCollectionByNameOrId('producao_itens');
    for (const f of [
      'formato',
      'recheio',
      'prioridade',
      'hora_limite',
      'unidades_previstas',
    ]) {
      itens.fields.removeByName(f);
    }
    app.save(itens);
  },
);
