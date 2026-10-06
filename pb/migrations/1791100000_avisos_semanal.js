/// <reference path="../pb_data/types.d.ts" />

// Resumo semanal — 1.107.0: `avisos_config` ganha o interruptor, o dia da semana
// (1 = segunda ... 7 = domingo) e a data do último envio semanal.
migrate(
  (app) => {
    const c = app.findCollectionByNameOrId('avisos_config');
    if (!c.fields.getByName('semanal_ativo')) {
      c.fields.add(new Field({ type: 'bool', name: 'semanal_ativo', required: false }));
    }
    if (!c.fields.getByName('semanal_dia')) {
      c.fields.add(new Field({ type: 'number', name: 'semanal_dia', required: false, min: 1, max: 7, onlyInt: true }));
    }
    if (!c.fields.getByName('ultimo_semanal')) {
      c.fields.add(new Field({ type: 'text', name: 'ultimo_semanal', required: false, max: 10 }));
    }
    app.save(c);
  },
  (app) => {
    const c = app.findCollectionByNameOrId('avisos_config');
    for (const n of ['semanal_ativo', 'semanal_dia', 'ultimo_semanal']) {
      if (c.fields.getByName(n)) c.fields.removeByName(n);
    }
    app.save(c);
  },
);
