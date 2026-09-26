/// <reference path="../pb_data/types.d.ts" />

// Análise de ficheiros grandes por janelas de páginas (ver faturas_lote.js).
//
//   POST /api/gc_turnkey/faturas/{id}/preparar          -> { paginas, proxima, retomado }
//   POST /api/gc_turnkey/faturas/{id}/analisar-parte    -> { feito, proxima, paginas, documentos }
//   POST /api/gc_turnkey/faturas/{id}/concluir-analise  -> { faturas, dividido, duplicadas }

routerAdd(
  'POST',
  '/api/gc_turnkey/faturas/{id}/preparar',
  (e) => {
    const lote = require(`${__hooks}/faturas_lote.js`);
    const r = lote.prepararLote(e.app, lote.carregar(e));
    if (!r.ok) throw new ApiError(r.code || 500, r.message, null);
    return e.json(200, r);
  },
  $apis.requireAuth('users', '_superusers'),
);

routerAdd(
  'POST',
  '/api/gc_turnkey/faturas/{id}/analisar-parte',
  (e) => {
    const lote = require(`${__hooks}/faturas_lote.js`);
    const r = lote.analisarProximaParte(e.app, lote.carregar(e));
    if (!r.ok) throw new ApiError(r.code || 502, r.message, null);
    return e.json(200, r);
  },
  $apis.requireAuth('users', '_superusers'),
);

routerAdd(
  'POST',
  '/api/gc_turnkey/faturas/{id}/concluir-analise',
  (e) => {
    const lote = require(`${__hooks}/faturas_lote.js`);
    const fatura = lote.carregar(e);
    const r = lote.concluirLote(e.app, fatura);
    if (!r.ok) throw new ApiError(r.code || 502, r.message, null);
    return e.json(200, {
      estado: 'analisada',
      provider: r.provider,
      faturas: r.faturas || [fatura.id],
      dividido: !!r.dividido,
      duplicadas: r.duplicadas || 0,
    });
  },
  $apis.requireAuth('users', '_superusers'),
);
