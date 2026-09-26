/// <reference path="../pb_data/types.d.ts" />

// Faturas: só o PROPRIETÁRIO edita (fornecedor, número, data, totais) e apaga.
// Apagar passa a ser "esconder" (`apagada`): a fatura e o ficheiro ficam na base
// de dados (entram nos backups) e o proprietário pode restaurá-la. Cada alteração
// fica no `historico` (entidade_tipo = 'fatura'), com os valores antes e depois
// (ver pb/hooks/faturas_edicao.pb.js).

migrate(
  (app) => {
    const faturas = app.findCollectionByNameOrId('faturas');
    if (!faturas.fields.getByName('apagada')) {
      faturas.fields.add(new Field({ type: 'bool', name: 'apagada', required: false }));
      faturas.fields.add(new Field({ type: 'date', name: 'apagada_em', required: false }));
      faturas.fields.add(new Field({ type: 'text', name: 'apagada_por', required: false, max: 200 }));
    }
    const soDono = (r) => (r ? r.replace("@request.auth.papel != 'viewer'", "@request.auth.papel = 'owner'") : r);
    faturas.updateRule = soDono(faturas.updateRule);
    faturas.deleteRule = soDono(faturas.deleteRule);
    app.save(faturas);

    const hist = app.findCollectionByNameOrId('historico');
    const f = hist.fields.getByName('entidade_tipo');
    if (f && f.values.indexOf('fatura') < 0) {
      f.values = f.values.concat(['fatura']);
      app.save(hist);
    }
  },
  (app) => {
    const faturas = app.findCollectionByNameOrId('faturas');
    faturas.fields.removeByName('apagada');
    faturas.fields.removeByName('apagada_em');
    faturas.fields.removeByName('apagada_por');
    const aTodos = (r) => (r ? r.replace("@request.auth.papel = 'owner'", "@request.auth.papel != 'viewer'") : r);
    faturas.updateRule = aTodos(faturas.updateRule);
    faturas.deleteRule = aTodos(faturas.deleteRule);
    app.save(faturas);

    const hist = app.findCollectionByNameOrId('historico');
    const f = hist.fields.getByName('entidade_tipo');
    if (f) {
      f.values = f.values.filter((v) => v !== 'fatura');
      app.save(hist);
    }
  },
);
