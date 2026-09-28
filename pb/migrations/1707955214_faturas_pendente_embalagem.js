/// <reference path="../pb_data/types.d.ts" />

// Duas melhorias nas faturas:
//
// 1. Aplicar por partes. Nem sempre há informação para decidir logo uma linha
//    (falta saber a marca, o preço…). `faturas_itens` passa a guardar o ÍNDICE
//    da linha (`linha_index`) e a ação `pendente` (distinta de `ignorar`: não é
//    "não interessa", é "ainda não decidi"). O endpoint `/aplicar` deixa de
//    apagar e recriar TODAS as linhas — só toca nas que ainda não tinham sido
//    aplicadas (por índice), por isso dá para aplicar só o que já está decidido
//    e voltar mais tarde às pendentes, sem repetir trabalho nem duplicar preços
//    ou movimentos de stock. `faturas.pendentes_linhas` guarda quantas ficaram
//    por decidir, para a lista mostrar "N por rever" sem ter de abrir a fatura.
//
// 2. Embalagens (caixas, sacos, adesivos…) também podem vir na fatura — passam
//    a poder ligar-se a um registo de `embalagens` (em vez de ingrediente ou
//    consumível). `embalagens.nomes_fatura` aprende o texto da fatura, como já
//    acontece com os produtos de compra e os consumíveis.

migrate(
  (app) => {
    const itens = app.findCollectionByNameOrId('faturas_itens');
    if (!itens.fields.getByName('linha_index')) {
      itens.fields.add(new Field({ type: 'number', name: 'linha_index', required: false, min: 0 }));
    }
    const acao = itens.fields.getByName('acao');
    if (acao.values.indexOf('pendente') < 0) {
      acao.values = acao.values.concat(['pendente']);
    }
    if (!itens.fields.getByName('embalagem')) {
      const embalagens = app.findCollectionByNameOrId('embalagens');
      itens.fields.add(
        new Field({
          type: 'relation',
          name: 'embalagem',
          required: false,
          maxSelect: 1,
          collectionId: embalagens.id,
          cascadeDelete: false,
        }),
      );
    }
    itens.indexes = itens.indexes.concat([
      'CREATE INDEX `idx_faturas_itens_fatura_indice` ON `faturas_itens` (`fatura`, `linha_index`)',
    ]);
    app.save(itens);

    const faturas = app.findCollectionByNameOrId('faturas');
    if (!faturas.fields.getByName('pendentes_linhas')) {
      faturas.fields.add(new Field({ type: 'number', name: 'pendentes_linhas', required: false, min: 0 }));
    }
    app.save(faturas);

    const embalagens = app.findCollectionByNameOrId('embalagens');
    if (!embalagens.fields.getByName('nomes_fatura')) {
      embalagens.fields.add(new Field({ type: 'json', name: 'nomes_fatura', required: false, maxSize: 20000 }));
    }
    app.save(embalagens);
  },
  (app) => {
    const itens = app.findCollectionByNameOrId('faturas_itens');
    itens.fields.removeByName('linha_index');
    itens.fields.removeByName('embalagem');
    const acao = itens.fields.getByName('acao');
    acao.values = acao.values.filter((v) => v !== 'pendente');
    itens.indexes = itens.indexes.filter(
      (i) => i.indexOf('idx_faturas_itens_fatura_indice') < 0,
    );
    app.save(itens);

    const faturas = app.findCollectionByNameOrId('faturas');
    faturas.fields.removeByName('pendentes_linhas');
    app.save(faturas);

    const embalagens = app.findCollectionByNameOrId('embalagens');
    embalagens.fields.removeByName('nomes_fatura');
    app.save(embalagens);
  },
);
