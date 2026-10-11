/// <reference path="../pb_data/types.d.ts" />

// Imagens nas tarefas da equipa (2.23.0): `tarefas.imagens`, até 8 fotos por
// tarefa (JPEG, PNG ou WebP, até 10 MB cada).
//
// Os ficheiros são PROTEGIDOS: só se veem com um token de quem está autenticado
// (as regras de leitura de `tarefas` valem também para as imagens, por isso
// outra empresa nunca as vê). Quem pode editar a tarefa (todos menos a
// Leitura) junta e tira imagens; a regra de atualização não mudou.
migrate(
  (app) => {
    const c = app.findCollectionByNameOrId('tarefas');
    if (!c.fields.getByName('imagens')) {
      c.fields.add(
        new Field({
          type: 'file',
          name: 'imagens',
          required: false,
          maxSelect: 8,
          maxSize: 10485760,
          mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
          thumbs: ['0x160'],
          protected: true,
        }),
      );
      app.save(c);
    }
  },
  (app) => {
    const c = app.findCollectionByNameOrId('tarefas');
    c.fields.removeByName('imagens');
    app.save(c);
  },
);
