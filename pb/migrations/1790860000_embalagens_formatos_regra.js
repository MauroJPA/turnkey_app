/// <reference path="../pb_data/types.d.ts" />

// Corrige a regra de criação/edição de `embalagens` quando NENHUM formato de
// cookie é escolhido ("em branco serve para qualquer formato"): a app envia
// `formatos_cookie: []` e a regra comparava a lista vazia com '' — o que
// falhava, e a embalagem não era criada ("Failed to create record" ao
// aplicar uma fatura, por exemplo). A comparação certa para listas é o
// modificador `:length`.
migrate(
  (app) => {
    const embalagens = app.findCollectionByNameOrId('embalagens');
    const antiga = "@request.body.formatos_cookie = ''";
    const nova = '@request.body.formatos_cookie:length = 0';
    for (const campo of ['createRule', 'updateRule']) {
      // as regras são apontadores na API JS: forçar para texto
      const regra = embalagens[campo] == null ? '' : String(embalagens[campo]);
      if (regra.includes(antiga)) {
        embalagens[campo] = regra.split(antiga).join(nova);
      }
    }
    app.save(embalagens);
  },
  (app) => {
    const embalagens = app.findCollectionByNameOrId('embalagens');
    const antiga = "@request.body.formatos_cookie = ''";
    const nova = '@request.body.formatos_cookie:length = 0';
    for (const campo of ['createRule', 'updateRule']) {
      const regra = embalagens[campo] == null ? '' : String(embalagens[campo]);
      if (regra.includes(nova)) {
        embalagens[campo] = regra.split(nova).join(antiga);
      }
    }
    app.save(embalagens);
  },
);
