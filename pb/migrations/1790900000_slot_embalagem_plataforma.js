/// <reference path="../pb_data/types.d.ts" />

// Ficha técnica: novo bloco "Embalagem para plataformas" (sacos de entrega,
// selos, caixas extra… que só se usam nas vendas por Uber Eats, Glovo, etc.).
// É mais um valor do `slot` de `itens_ficha`. O custo deste bloco NÃO entra no
// `custo_produto` da ficha (custo na loja): mostra-se à parte, para saber o
// custo do produto quando vai para uma plataforma.

migrate(
  (app) => {
    const itens = app.findCollectionByNameOrId('itens_ficha');
    const slot = itens.fields.getByName('slot');
    if (slot && slot.values.indexOf('embalagem_plataforma') < 0) {
      slot.values = slot.values.concat(['embalagem_plataforma']);
      app.save(itens);
    }
  },
  (app) => {
    const itens = app.findCollectionByNameOrId('itens_ficha');
    const slot = itens.fields.getByName('slot');
    if (slot) {
      slot.values = slot.values.filter((v) => v !== 'embalagem_plataforma');
      app.save(itens);
    }
  },
);
