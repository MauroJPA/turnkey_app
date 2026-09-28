/// <reference path="../pb_data/types.d.ts" />

// Faturas: o administrador passa a poder corrigir (fornecedor, número, data,
// totais) e apagar/restaurar, tal como já podia corrigir a marca de uma linha
// (endpoint /corrigir-item) — até agora só o proprietário conseguia, o que
// obrigava a reportar o problema por fora da app quando quem estava a usá-la
// era um administrador.

migrate(
  (app) => {
    const faturas = app.findCollectionByNameOrId('faturas');
    const comAdmin = (r) =>
      r ? r.replace("@request.auth.papel = 'owner'", "(@request.auth.papel = 'owner' || @request.auth.papel = 'admin')") : r;
    faturas.updateRule = comAdmin(faturas.updateRule);
    faturas.deleteRule = comAdmin(faturas.deleteRule);
    app.save(faturas);
  },
  (app) => {
    const faturas = app.findCollectionByNameOrId('faturas');
    const soDono = (r) =>
      r ? r.replace("(@request.auth.papel = 'owner' || @request.auth.papel = 'admin')", "@request.auth.papel = 'owner'") : r;
    faturas.updateRule = soDono(faturas.updateRule);
    faturas.deleteRule = soDono(faturas.deleteRule);
    app.save(faturas);
  },
);
