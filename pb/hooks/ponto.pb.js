/// <reference path="../pb_data/types.d.ts" />

// Registo de ponto: estado para o quiosque.
//
//   GET /api/gc_turnkey/ponto/estado
//     -> { pessoas: [{ pessoa, tipo, dataHora }] }
//   A última marcação (das últimas 36 horas) de cada pessoa da empresa, para o
//   quiosque saber se oferece "Entrada", "Pausa" ou "Saída". Não devolve nomes
//   nem mais nada; quem tem papel de leitura não vê.
//
// NOTA: cada handler corre isolado — nada de constantes ou funções por fora.

routerAdd(
  'GET',
  '/api/gc_turnkey/ponto/estado',
  (e) => {
    const auth = e.auth;
    if (!auth || auth.collection().name !== 'users' || !auth.getString('empresa')) {
      throw new ForbiddenError('Autenticação necessária.');
    }
    if (auth.getString('papel') === 'viewer') {
      throw new ForbiddenError('Sem permissão.');
    }
    const desde = new Date(Date.now() - 36 * 3600 * 1000).toISOString().replace('T', ' ');
    const regs = e.app.findRecordsByFilter(
      'ponto_registos',
      'empresa = {:e} && data_hora >= {:d}',
      '-data_hora',
      1000,
      0,
      { e: auth.getString('empresa'), d: desde },
    );
    const vistos = {};
    const pessoas = [];
    for (const r of regs) {
      const p = r.getString('pessoa');
      if (vistos[p]) continue;
      vistos[p] = true;
      pessoas.push({
        pessoa: p,
        tipo: r.getString('tipo'),
        dataHora: String(r.getString('data_hora')),
      });
    }
    return e.json(200, { pessoas });
  },
  $apis.requireAuth('users'),
);
