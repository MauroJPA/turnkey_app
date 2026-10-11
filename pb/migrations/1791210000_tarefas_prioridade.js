/// <reference path="../pb_data/types.d.ts" />

// Prioridade (criticidade) de cada tarefa (2.24.0): `tarefas.prioridade` =
// baixa | normal | alta | critica. Vazio conta como "normal", por isso as
// tarefas que já existem não mudam. As regras de atualização não mudam: quem
// pode editar a tarefa muda a prioridade.
migrate(
  (app) => {
    const c = app.findCollectionByNameOrId('tarefas');
    if (!c.fields.getByName('prioridade')) {
      c.fields.add(
        new Field({
          type: 'select',
          name: 'prioridade',
          required: false,
          maxSelect: 1,
          values: ['baixa', 'normal', 'alta', 'critica'],
        }),
      );
      app.save(c);
    }
  },
  (app) => {
    const c = app.findCollectionByNameOrId('tarefas');
    c.fields.removeByName('prioridade');
    app.save(c);
  },
);
