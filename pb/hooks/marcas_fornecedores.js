/// <reference path="../pb_data/types.d.ts" />

// Marcas e fornecedores são TEXTO livre, escrito à mão ou lido por IA de
// faturas diferentes — por isso o mesmo fornecedor real acaba às vezes com
// vários nomes ligeiramente diferentes ("Recheio", "Recheio Cash & Carry,
// S.A.", "Recheio Cash & Carry, SA"). juntarMarcasFornecedores substitui
// todos os valores escolhidos por UM só nome final, em todos os registos da
// empresa que os têm — sem inventar semelhanças sozinho (é a pessoa que
// escolhe o que é o mesmo fornecedor).
//
//   juntarMarcasFornecedores(app, empresaId, tipo, valores, destino)
//     tipo = 'marca' | 'fornecedor'. `valores` = os textos a substituir
//     (o próprio `destino`, se vier na lista, é ignorado). `marca` só existe
//     em ingrediente_produtos/consumiveis; `fornecedor` também em embalagens.
//     Gravar ingrediente_produtos dispara sozinho a sincronização do
//     ingrediente genérico (produtos.pb.js → recalcularGenerico).

function normalizarEspacos(s) {
  return String(s || '')
    .replace(/\s+/g, ' ')
    .trim();
}

function juntarMarcasFornecedores(app, empresaId, tipo, valores, destinoBruto) {
  if (tipo !== 'marca' && tipo !== 'fornecedor') {
    throw new BadRequestError('Tipo tem de ser "marca" ou "fornecedor".');
  }
  const destino = normalizarEspacos(destinoBruto).substring(0, 200);
  if (!destino) throw new BadRequestError('Falta o nome final.');
  const lista = Array.isArray(valores) ? valores : [];
  const origens = [];
  const vistos = {};
  for (let i = 0; i < lista.length; i++) {
    const v = normalizarEspacos(lista[i]);
    if (!v || v === destino || vistos[v]) continue;
    vistos[v] = true;
    origens.push(v);
  }
  if (!origens.length) {
    throw new BadRequestError('Escolhe pelo menos um valor diferente do nome final.');
  }

  const colecoes = tipo === 'marca'
    ? ['ingrediente_produtos', 'consumiveis']
    : ['ingrediente_produtos', 'consumiveis', 'embalagens'];

  let alterados = 0;
  app.runInTransaction((tx) => {
    for (const colecao of colecoes) {
      for (const origem of origens) {
        const recs = tx.findRecordsByFilter(
          colecao,
          tipo + ' = {:v} && empresa = {:e}',
          '',
          0,
          0,
          { v: origem, e: empresaId },
        );
        for (const r of recs) {
          r.set(tipo, destino);
          tx.save(r);
          alterados++;
        }
      }
    }
  });

  return { alterados: alterados, destino: destino, origens: origens };
}

module.exports = { juntarMarcasFornecedores, normalizarEspacos };
