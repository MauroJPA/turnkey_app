/// <reference path="../pb_data/types.d.ts" />

// Embalagens: uma característica livre (ex.: "kraft com janela", "transparente
// 250 ml") para distinguir variantes do mesmo tipo, o uso (individual, em
// múltiplos, a granel…) e a que formatos de cookie se destina (vazio = qualquer
// formato) — para ajudar a escolher a embalagem certa ao montar uma ficha
// técnica ou ao ligar uma linha de fatura.

migrate(
  (app) => {
    const embalagens = app.findCollectionByNameOrId('embalagens');
    const formatos = app.findCollectionByNameOrId('formatos_cookie');
    if (!embalagens.fields.getByName('caracteristica')) {
      embalagens.fields.add(
        new Field({ type: 'text', name: 'caracteristica', required: false, max: 200 }),
      );
    }
    if (!embalagens.fields.getByName('uso')) {
      embalagens.fields.add(
        new Field({
          type: 'select',
          name: 'uso',
          required: false,
          maxSelect: 1,
          values: ['individual', 'multiplo', 'granel', 'outro'],
        }),
      );
    }
    let novaRelacao = false;
    if (!embalagens.fields.getByName('formatos_cookie')) {
      embalagens.fields.add(
        new Field({
          type: 'relation',
          name: 'formatos_cookie',
          required: false,
          maxSelect: 999,
          collectionId: formatos.id,
          cascadeDelete: false,
        }),
      );
      novaRelacao = true;
    }
    // multi-select: a regra só garante "pelo menos um" da mesma empresa — a
    // validação de que TODOS pertencem à empresa fica no hook
    // embalagens_validacao.pb.js (onRecordCreate/UpdateRequest).
    if (novaRelacao) {
      const clausula =
        "(@request.body.formatos_cookie:isset = false || @request.body.formatos_cookie = '' || " +
        '@request.body.formatos_cookie.empresa = @request.auth.empresa)';
      embalagens.createRule = '(' + embalagens.createRule + ') && ' + clausula;
      embalagens.updateRule = '(' + embalagens.updateRule + ') && ' + clausula;
    }
    app.save(embalagens);
  },
  (app) => {
    const embalagens = app.findCollectionByNameOrId('embalagens');
    embalagens.fields.removeByName('caracteristica');
    embalagens.fields.removeByName('uso');
    embalagens.fields.removeByName('formatos_cookie');
    const tirar = (r) => {
      const i = r.lastIndexOf(' && (@request.body.formatos_cookie:isset');
      return i < 0 ? r : r.substring(0, i).replace(/^\((.*)\)$/, '$1');
    };
    embalagens.createRule = tirar(embalagens.createRule);
    embalagens.updateRule = tirar(embalagens.updateRule);
    app.save(embalagens);
  },
);
