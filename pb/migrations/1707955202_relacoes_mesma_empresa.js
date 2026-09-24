/// <reference path="../pb_data/types.d.ts" />

// Isolamento entre empresas nas RELAÇÕES: um utilizador da empresa B não pode
// criar/alterar um registo seu a apontar para um registo da empresa A (ex.:
// linha de receita a apontar para um ingrediente de outra empresa), o que
// deixaria misturar preços/custos entre empresas. Acrescenta às regras de
// criar e atualizar, para cada relação simples (maxSelect = 1) entre coleções
// que têm `empresa`:
//   (@request.body.X:isset = false || @request.body.X = '' ||
//    @request.body.X.empresa = @request.auth.empresa)
//
// NOTA: coleções/relações criadas DEPOIS desta migration têm de levar a mesma
// cláusula (o teste test/security/seguranca.py avisa se faltar).

function clausula(nome) {
  return (
    "(@request.body." + nome + ":isset = false || @request.body." + nome + " = '' || " +
    "@request.body." + nome + ".empresa = @request.auth.empresa)"
  );
}

migrate(
  (app) => {
    const todas = app.findAllCollections();
    const temEmpresa = {};
    for (const c of todas) {
      if (c.fields.getByName('empresa')) temEmpresa[c.id] = true;
    }
    for (const c of todas) {
      if (!temEmpresa[c.id] || c.name.startsWith('_')) continue;
      const extra = [];
      for (const f of c.fields) {
        if (f.type() !== 'relation') continue;
        if (f.getName() === 'empresa') continue;
        if (!temEmpresa[f.collectionId]) continue;
        if (f.maxSelect !== 1) continue;
        extra.push(clausula(f.getName()));
      }
      if (!extra.length) continue;
      const juntar = (regra) => (regra === null ? null : '(' + regra + ') && ' + extra.join(' && '));
      c.createRule = juntar(c.createRule);
      c.updateRule = juntar(c.updateRule);
      app.save(c);
    }

    // sugestões: só em nome da própria empresa/utilizador
    const sug = app.findCollectionByNameOrId('sugestoes');
    sug.createRule =
      "@request.auth.id != '' && " +
      "(@request.body.empresa:isset = false || @request.body.empresa = '' || @request.body.empresa = @request.auth.empresa) && " +
      "(@request.body.autor:isset = false || @request.body.autor = '' || @request.body.autor = @request.auth.id)";
    app.save(sug);
  },
  (app) => {
    // Reversão: retira as cláusulas acrescentadas (mantém as regras originais).
    for (const c of app.findAllCollections()) {
      const tirar = (regra) => {
        if (!regra) return regra;
        let r = regra;
        for (const f of c.fields) {
          if (f.type() !== 'relation') continue;
          r = r.split(' && ' + clausula(f.getName())).join('');
        }
        return r.replace(/^\((.*)\)$/, '$1');
      };
      if (c.name.startsWith('_') || c.name === 'users') continue;
      c.createRule = tirar(c.createRule);
      c.updateRule = tirar(c.updateRule);
      app.save(c);
    }
    const sug = app.findCollectionByNameOrId('sugestoes');
    sug.createRule = "@request.auth.id != ''";
    app.save(sug);
  },
);
