/// <reference path="../pb_data/types.d.ts" />

// Financeiro (F-FIN-6) — sincronização com o Vendus (POS/faturação da
// Gookie). Traz as vendas (documentos FT/FS/FR/FG, não cancelados) como
// `vendas`+`vendas_itens` (origem 'vendus'), com emparelhamento automático
// por nome à ficha técnica — mesma lógica da importação CSV.
//
//   POST /api/turnkey/vendus/sincronizar
//     -> { vendasCriadas, duplicadasIgnoradas, itensCriados, itensSemFicha }
//     -> 503 se faltar VENDUS_API_KEY no ambiente do servidor
//
//   VENDUS_API_KEY         API KEY gerada em Apps → API na conta Vendus
//   VENDUS_SYNC_EMPRESA    id da empresa para o cron horário (sem auth de
//                          utilizador; o botão manual usa a empresa de quem
//                          está autenticado, não precisa desta variável)
//
// Sem VENDUS_API_KEY, nem o botão nem o cron fazem nada (503 / log e volta a
// tentar na próxima hora). Nunca colocar a chave na app — só no servidor.

routerAdd(
  'POST',
  '/api/turnkey/vendus/sincronizar',
  (e) => {
    const auth = e.auth;
    if (!auth || auth.collection().name !== 'users') {
      throw new ForbiddenError('Autenticação necessária.');
    }
    if (auth.getString('papel') === 'viewer') {
      throw new ForbiddenError('Sem permissão.');
    }
    const empresaId = auth.getString('empresa');
    const core = require(`${__hooks}/vendus_core.js`);
    const r = core.sincronizarEmpresa(e.app, empresaId, {});
    if (!r.ok) throw new ApiError(r.code || 502, r.message, null);

    return e.json(200, {
      vendasCriadas: r.vendasCriadas,
      duplicadasIgnoradas: r.duplicadasIgnoradas,
      itensCriados: r.itensCriados,
      itensSemFicha: r.itensSemFicha,
    });
  },
  $apis.requireAuth('users'),
);

// De hora a hora, só se VENDUS_SYNC_EMPRESA estiver definida.
cronAdd('vendus_sync', '0 * * * *', () => {
  const empId = $os.getenv('VENDUS_SYNC_EMPRESA');
  if (!empId) return;

  const core = require(`${__hooks}/vendus_core.js`);
  const r = core.sincronizarEmpresa($app, empId, {});
  if (!r.ok) {
    console.log('[vendus] sincronização falhou: ' + r.message);
    return;
  }
  if (r.vendasCriadas > 0) {
    console.log(
      '[vendus] ' +
        r.vendasCriadas +
        ' venda(s) sincronizada(s), ' +
        r.itensSemFicha +
        ' linha(s) sem produto identificado.',
    );
  }
});
