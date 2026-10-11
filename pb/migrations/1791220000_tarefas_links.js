/// <reference path="../pb_data/types.d.ts" />

// Links nas tarefas (2.26.0): `tarefas.links` = lista JSON de
// {"t": "o que é", "u": "https://…"} (até 20). A app só abre endereços
// http/https. As regras de atualização não mudam: quem edita a tarefa, edita
// os links.
migrate(
  (app) => {
    const c = app.findCollectionByNameOrId('tarefas');
    if (!c.fields.getByName('links')) {
      c.fields.add(new Field({ type: 'json', name: 'links', required: false, maxSize: 20000 }));
      app.save(c);
    }
  },
  (app) => {
    const c = app.findCollectionByNameOrId('tarefas');
    c.fields.removeByName('links');
    app.save(c);
  },
);
