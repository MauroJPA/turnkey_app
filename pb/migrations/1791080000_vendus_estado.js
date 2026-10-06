/// <reference path="../pb_data/types.d.ts" />

// Estado da sincronização com o Vendus — 1.101.0.
// O servidor sincroniza de hora a hora; estes campos guardam quando foi a
// última tentativa, a última que correu bem e o resultado, para a app mostrar
// "vendas atualizadas às 14:05" e avisar se deixar de sincronizar.
migrate(
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');
    let mudou = false;
    for (const [nome, max] of [
      ['vendus_tentativa_em', 40],
      ['vendus_ok_em', 40],
      ['vendus_resultado', 300],
    ]) {
      if (!empresas.fields.getByName(nome)) {
        empresas.fields.add(new Field({ type: 'text', name: nome, required: false, max: max }));
        mudou = true;
      }
    }
    if (mudou) app.save(empresas);
  },
  (app) => {
    const empresas = app.findCollectionByNameOrId('empresas');
    for (const nome of ['vendus_tentativa_em', 'vendus_ok_em', 'vendus_resultado']) {
      if (empresas.fields.getByName(nome)) empresas.fields.removeByName(nome);
    }
    app.save(empresas);
  },
);
