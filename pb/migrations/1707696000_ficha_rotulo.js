/// <reference path="../pb_data/types.d.ts" />

// Dados do produto final para a etiqueta e a página "Produtos":
// descrição curta, prazo de validade (dias a contar da data de fabrico) e modo
// de conservação.

migrate(
  (app) => {
    const c = app.findCollectionByNameOrId('fichas_tecnicas');
    if (!c.fields.getByName('descricao')) {
      c.fields.add(new Field({ type: 'text', name: 'descricao', required: false, max: 300 }));
    }
    if (!c.fields.getByName('validade_dias')) {
      c.fields.add(new Field({ type: 'number', name: 'validade_dias', required: false, min: 0 }));
    }
    if (!c.fields.getByName('conservacao')) {
      c.fields.add(new Field({ type: 'text', name: 'conservacao', required: false, max: 200 }));
    }
    app.save(c);
  },
  (app) => {
    const c = app.findCollectionByNameOrId('fichas_tecnicas');
    c.fields.removeByName('descricao');
    c.fields.removeByName('validade_dias');
    c.fields.removeByName('conservacao');
    app.save(c);
  },
);
