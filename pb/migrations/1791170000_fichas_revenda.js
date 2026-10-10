/// <reference path="../pb_data/types.d.ts" />

// Produtos para venda (2.22.0): fichas técnicas (produzidas por nós) e
// produtos de REVENDA (comprados já feitos: água, Coca-Cola, Compal…).
//
// `fichas_tecnicas.revenda`: o produto é de revenda. Usa o mesmo detalhe
// (custo pela compra, preço, canais, nutrição, histórico, etiqueta), mas não
// entra na produção nem na contagem de fornadas.
// `fichas_tecnicas.iva_proprio` + `iva_pct`: taxa de IVA própria do produto
// (as bebidas costumam ter outra taxa); sem isso, vale a das Configurações.
migrate(
  (app) => {
    const fichas = app.findCollectionByNameOrId('fichas_tecnicas');
    fichas.fields.add(new BoolField({ name: 'revenda', required: false }));
    fichas.fields.add(new BoolField({ name: 'iva_proprio', required: false }));
    fichas.fields.add(new NumberField({ name: 'iva_pct', required: false, min: 0, max: 100 }));
    app.save(fichas);
  },
  (app) => {
    const fichas = app.findCollectionByNameOrId('fichas_tecnicas');
    for (const n of ['revenda', 'iva_proprio', 'iva_pct']) fichas.fields.removeByName(n);
    app.save(fichas);
  },
);
