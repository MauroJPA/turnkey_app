/// <reference path="../pb_data/types.d.ts" />

// Fase 5 — categoria nos itens que não são de receita.
//
// A lista de compras e o inventário "Outros" (itens livres) passam a poder
// classificar cada item: Consumível, Limpeza, Equipamento, Mobiliário,
// Ferramenta, Outro. Serve para organizar o "inventário geral da loja"
// (mesas, bancadas, facas, sabão, sacos de lixo, etc.).

migrate(
  (app) => {
    const addCategoria = (nome) => {
      const c = app.findCollectionByNameOrId(nome);
      if (!c.fields.getByName('categoria')) {
        c.fields.add(
          new Field({ type: 'text', name: 'categoria', required: false, max: 40 }),
        );
      }
      app.save(c);
    };
    addCategoria('lista_compras');
    addCategoria('inventario');
    addCategoria('movimentos_inventario');
  },
  (app) => {
    for (const nome of ['lista_compras', 'inventario', 'movimentos_inventario']) {
      const c = app.findCollectionByNameOrId(nome);
      c.fields.removeByName('categoria');
      app.save(c);
    }
  },
);
