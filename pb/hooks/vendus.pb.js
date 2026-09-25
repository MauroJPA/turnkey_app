/// <reference path="../pb_data/types.d.ts" />

// Financeiro (F-FIN-6) — sincronização com o Vendus (POS/faturação).
// Traz as vendas (documentos não cancelados que não sejam
// orçamentos/guias/encomendas/notas de crédito ou débito — ver
// TIPOS_NAO_VENDA em vendus_core.js) como `vendas`+`vendas_itens` (origem
// 'vendus'), com emparelhamento automático por nome à ficha técnica —
// mesma lógica da importação CSV.
//
//   POST /api/gc_turnkey/vendus/sincronizar
//     body opcional: { desde?: "YYYY-MM-DD", ate?: "YYYY-MM-DD" }
//     -> { vendasCriadas, duplicadasIgnoradas, itensCriados, itensSemFicha }
//     -> 503 se faltar VENDUS_API_KEY no ambiente do servidor
//
// Sem `desde`, continua a partir de `empresas.vendus_ultima_sincronizacao`
// (ou dos últimos 90 dias, se for a primeira vez). Com `desde`, ignora esse
// progresso e volta a pedir ao Vendus a partir dessa data — útil para
// reimportar histórico mais antigo (ex.: se a marca de progresso avançou
// antes de tempo, como aconteceu por causa de um bug já corrigido).
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
  '/api/gc_turnkey/vendus/sincronizar',
  (e) => {
    const auth = e.auth;
    if (!auth || auth.collection().name !== 'users') {
      throw new ForbiddenError('Autenticação necessária.');
    }
    if (auth.getString('papel') === 'viewer') {
      throw new ForbiddenError('Sem permissão.');
    }
    const empresaId = auth.getString('empresa');
    const body = e.requestInfo().body || {};
    const desde = (body.desde || '').toString().substring(0, 10);
    const ate = (body.ate || '').toString().substring(0, 10);
    const core = require(`${__hooks}/vendus_core.js`);
    const r = core.sincronizarEmpresa(e.app, empresaId, { desde: desde, ate: ate });
    if (!r.ok) {
      // Diagnóstico útil no próprio erro: quantos documentos o Vendus
      // devolveu e que tipos tinham, para perceber se o filtro de tipo de
      // documento está a excluir tudo (em vez de "0 vendas" sem explicação).
      const diag =
        r.totalDocumentosRecebidos != null
          ? ` [recebidos: ${r.totalDocumentosRecebidos}, tipos: ${JSON.stringify(r.tiposDocumentosVistos || {})}]`
          : '';
      throw new ApiError(r.code || 502, r.message + diag, null);
    }

    return e.json(200, {
      vendasCriadas: r.vendasCriadas,
      duplicadasIgnoradas: r.duplicadasIgnoradas,
      itensCriados: r.itensCriados,
      itensSemFicha: r.itensSemFicha,
      totalDocumentosRecebidos: r.totalDocumentosRecebidos,
      tiposDocumentosVistos: r.tiposDocumentosVistos,
    });
  },
  $apis.requireAuth('users'),
);

// De hora a hora, para cada empresa com token do Vendus guardado (e ainda a
// empresa VENDUS_SYNC_EMPRESA, se usar o token do ambiente).
// (O handler é autocontido: não vê funções de topo do ficheiro.)
cronAdd('vendus_sync', '0 * * * *', () => {
  const ids = {};
  try {
    for (const r of $app.findRecordsByFilter('segredos_empresa', "servico = 'vendus'", '', 0, 0)) {
      ids[r.getString('empresa')] = true;
    }
  } catch (_) {}
  const env = $os.getenv('VENDUS_SYNC_EMPRESA');
  if (env) ids[env] = true;

  const core = require(`${__hooks}/vendus_core.js`);
  for (const empId of Object.keys(ids)) {
    const r = core.sincronizarEmpresa($app, empId, {});
    if (!r.ok) {
      console.log('[vendus] sincronização falhou (' + empId + '): ' + r.message);
      continue;
    }
    if (r.vendasCriadas > 0) {
      console.log(
        '[vendus] ' +
          empId +
          ': ' +
          r.vendasCriadas +
          ' venda(s) sincronizada(s), ' +
          r.itensSemFicha +
          ' linha(s) sem produto identificado.',
      );
    } else if (r.totalDocumentosRecebidos > 0) {
      console.log(
        '[vendus] ' +
          empId +
          ': 0 vendas novas, ' +
          r.totalDocumentosRecebidos +
          ' documento(s) recebidos do Vendus. Tipos vistos: ' +
          JSON.stringify(r.tiposDocumentosVistos || {}),
      );
    }
  }
});
