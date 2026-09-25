/// <reference path="../pb_data/types.d.ts" />

// Fase 5 — análise de faturas por IA (Anthropic) e aplicação aos ingredientes.
//
//   POST /api/gc_turnkey/faturas/{id}/analisar   { imagem(base64), mime }
//   POST /api/gc_turnkey/faturas/{id}/aplicar    { linhas: [...] }
//   GET  /api/gc_turnkey/faturas/export?de=&ate=
//
// A chave da IA vem de ANTHROPIC_API_KEY no ambiente do servidor. Nunca no app.

// --- POST /api/gc_turnkey/faturas/{id}/analisar --------------------------
routerAdd(
  'POST',
  '/api/gc_turnkey/faturas/{id}/analisar',
  (e) => {
    const auth = e.auth;
    const isSuper =
      auth && auth.collection() && auth.collection().name === '_superusers';
    const id = e.request.pathValue('id');
    const fatura = e.app.findRecordById('faturas', id);
    const empresaId = fatura.getString('empresa');
    if (!isSuper) {
      if (!auth || auth.collection().name !== 'users') {
        throw new ForbiddenError('Autenticação necessária.');
      }
      if (auth.getString('empresa') !== empresaId) {
        throw new ForbiddenError('Fatura de outra empresa.');
      }
      if (auth.getString('papel') === 'viewer') {
        throw new ForbiddenError('Sem permissão.');
      }
    }

    const body = e.requestInfo().body || {};
    const core = require(`${__hooks}/faturas_core.js`);
    const r = core.analisarFatura(e.app, id, {
      imagemBase64: (body.imagem || '').toString(),
      mime: (body.mime || 'image/jpeg').toString(),
    });
    if (!r.ok) throw new ApiError(r.code || 502, r.message, null);

    return e.json(200, {
      estado: 'analisada',
      provider: r.provider,
      dados: r.dados,
      faturas: r.faturas || [id],
      dividido: !!r.dividido,
      duplicadas: r.duplicadas || 0,
    });
  },
  $apis.requireAuth('users', '_superusers'),
);

// --- POST /api/gc_turnkey/faturas/{id}/aplicar --------------------------
routerAdd(
  'POST',
  '/api/gc_turnkey/faturas/{id}/aplicar',
  (e) => {
    const cascade = require(`${__hooks}/cascade.js`);
    const auth = e.auth;
    const isSuper =
      auth && auth.collection() && auth.collection().name === '_superusers';
    const id = e.request.pathValue('id');
    const fatura = e.app.findRecordById('faturas', id);
    const empresaId = fatura.getString('empresa');
    let autorId = null;
    if (!isSuper) {
      if (!auth || auth.collection().name !== 'users') {
        throw new ForbiddenError('Autenticação necessária.');
      }
      if (auth.getString('empresa') !== empresaId) {
        throw new ForbiddenError('Fatura de outra empresa.');
      }
      if (auth.getString('papel') === 'viewer') {
        throw new ForbiddenError('Sem permissão.');
      }
      autorId = auth.id;
    }

    const body = e.requestInfo().body || {};
    const linhas = Array.isArray(body.linhas) ? body.linhas : [];
    const numero = fatura.getString('numero');
    const nota = 'Fatura' + (numero ? ' ' + numero : '');

    // Data desta fatura (YYYY-MM-DD). Só atualiza o preço de um ingrediente se
    // esta fatura for igual ou mais recente do que a última atualização de
    // preço desse ingrediente — assim, subir uma fatura antiga não estraga um
    // preço mais recente.
    const soData = (s) => String(s || '').substring(0, 10);
    const dataFatura =
      soData(fatura.getString('data_fatura')) ||
      soData(fatura.getString('created'));

    let precos = 0;
    let precosIgnorados = 0;
    let movimentos = 0;

    e.app.runInTransaction((tx) => {
      // limpar linhas anteriores desta fatura
      const antigas = tx.findRecordsByFilter(
        'faturas_itens',
        'fatura = {:f}',
        '',
        0,
        0,
        { f: id },
      );
      for (const a of antigas) tx.delete(a);

      for (const l of linhas) {
        const acao = l.acao || 'ignorar';
        const ingId = l.ingredienteId || '';
        const consId = l.consumivelId || '';
        const q = Number(l.quantidadeG || 0);
        const pu = Number(l.precoUnitario || 0);
        const emb = Number(l.embalagemG || 0);

        // Limpeza / insumos: guarda o preço e o nome desta fatura no consumível
        // (sem stock). Os documentos (FDS…) ficam onde estão — a app mostra-os.
        if (acao !== 'ignorar' && consId && !ingId) {
          let cons = null;
          try {
            cons = tx.findRecordById('consumiveis', String(consId));
            if (cons.getString('empresa') !== empresaId) cons = null;
          } catch (_) {
            cons = null;
          }
          if (cons) {
            const prods = require(`${__hooks}/produtos.js`);
            const desc = prods.normalizarDescricao(l.descricaoFatura);
            let nomes = [];
            try {
              const v = JSON.parse(cons.getString('nomes_fatura') || '[]');
              if (Array.isArray(v)) nomes = v;
            } catch (_) {}
            if (desc && nomes.indexOf(desc) === -1) {
              nomes.push(desc);
              while (nomes.length > 50) nomes.shift();
              cons.set('nomes_fatura', nomes);
            }
            if (l.marca && !cons.getString('marca')) {
              cons.set('marca', String(l.marca).substring(0, 200));
            }
            if (!cons.getString('fornecedor') && fatura.getString('fornecedor')) {
              cons.set('fornecedor', fatura.getString('fornecedor'));
            }
            if (pu > 0 && (acao === 'preco' || acao === 'ambos')) {
              const ultima = soData(cons.getString('preco_atualizado_em'));
              if (!ultima || (dataFatura && dataFatura >= ultima)) {
                cons.set('preco', pu);
                cons.set(
                  'preco_atualizado_em',
                  (dataFatura || soData(new Date().toISOString())) + 'T00:00:00.000Z',
                );
                precos++;
              } else {
                precosIgnorados++;
              }
            }
            tx.save(cons);
          }
        }

        if (acao !== 'ignorar' && ingId) {
          if (acao === 'preco' || acao === 'ambos') {
            let ing;
            try {
              ing = tx.findRecordById('ingredientes', ingId);
            } catch (_) {
              ing = null;
            }
            if (ing && ing.getString('empresa') === empresaId && pu > 0) {
              // O preço fica no PRODUTO de compra (marca/embalagem); o custo do
              // ingrediente genérico passa a ser o da compra mais recente (hook).
              const prods = require(`${__hooks}/produtos.js`);
              const desc = prods.normalizarDescricao(l.descricaoFatura);
              const lerNomes = (rec) => {
                try {
                  const v = JSON.parse(rec.getString('nomes_fatura') || '[]');
                  return Array.isArray(v) ? v : [];
                } catch (_) {
                  return [];
                }
              };
              let prod = null;
              if (l.produtoId) {
                try {
                  prod = tx.findRecordById('ingrediente_produtos', String(l.produtoId));
                  if (prod.getString('ingrediente') !== ingId) prod = null;
                } catch (_) {
                  prod = null;
                }
              }
              if (!prod && desc) {
                const todos = tx.findRecordsByFilter(
                  'ingrediente_produtos',
                  'ingrediente = {:i}',
                  '',
                  0,
                  0,
                  { i: ingId },
                );
                for (const p of todos) {
                  if (lerNomes(p).indexOf(desc) !== -1) {
                    prod = p;
                    break;
                  }
                }
              }
              if (!prod) {
                prod = new Record(tx.findCollectionByNameOrId('ingrediente_produtos'));
                prod.set('empresa', empresaId);
                prod.set('ingrediente', ingId);
                prod.set(
                  'nome',
                  String(l.produtoNome || l.descricaoFatura || ing.getString('nome')).substring(0, 250),
                );
                prod.set('fornecedor', fatura.getString('fornecedor'));
              }
              if (l.marca && !prod.getString('marca')) {
                prod.set('marca', String(l.marca).substring(0, 200));
              }
              // aprende o nome desta fatura para emparelhar sozinho da próxima vez
              const nomes = lerNomes(prod);
              if (desc && nomes.indexOf(desc) === -1) {
                nomes.push(desc);
                while (nomes.length > 50) nomes.shift();
                prod.set('nomes_fatura', nomes);
              }
              const ultima = soData(prod.getString('preco_atualizado_em'));
              const maisRecente = !ultima || (dataFatura && dataFatura >= ultima);
              if (maisRecente) {
                const embEf =
                  emb > 0 ? emb : prod.getFloat('embalagem_g') || ing.getFloat('gramas_embalagem');
                prod.set('preco', pu);
                if (embEf > 0) prod.set('embalagem_g', embEf);
                // carimba com a data da fatura (não "agora"), para futuras
                // comparações usarem sempre a data do documento.
                prod.set(
                  'preco_atualizado_em',
                  (dataFatura || soData(new Date().toISOString())) + 'T00:00:00.000Z',
                );
                precos++;
              } else {
                precosIgnorados++;
              }
              tx.save(prod);
            }
          }
          if ((acao === 'stock' || acao === 'ambos') && q > 0) {
            cascade.aplicarMovimento(
              tx,
              { empresaId: empresaId, ingredienteId: ingId },
              q,
              'compra',
              { autorId: autorId, notas: nota, producaoId: null },
            );
            movimentos++;
          }
        }

        const row = new Record(tx.findCollectionByNameOrId('faturas_itens'));
        row.set('empresa', empresaId);
        row.set('fatura', id);
        if (ingId) row.set('ingrediente', ingId);
        else if (consId) row.set('consumivel', consId);
        row.set('descricao_fatura', String(l.descricaoFatura || ''));
        row.set('quantidade_g', q);
        row.set('preco_unitario', pu);
        row.set('total_linha', Number(l.totalLinha || 0));
        row.set('embalagem_g', emb);
        row.set('acao', acao);
        row.set('aplicado', acao !== 'ignorar' && (!!ingId || !!consId));
        tx.save(row);
      }

      fatura.set('estado', 'confirmada');
      tx.save(fatura);
    });

    return e.json(200, {
      precos: precos,
      precosIgnorados: precosIgnorados,
      movimentos: movimentos,
    });
  },
  $apis.requireAuth('users', '_superusers'),
);

// --- GET /api/gc_turnkey/faturas/export?de=&ate= ------------------------
routerAdd(
  'GET',
  '/api/gc_turnkey/faturas/export',
  (e) => {
    const auth = e.auth;
    const isSuper =
      auth && auth.collection() && auth.collection().name === '_superusers';
    let empresaId = e.requestInfo().query.empresa || '';
    if (!isSuper) {
      if (!auth || auth.collection().name !== 'users') {
        throw new ForbiddenError('Autenticação necessária.');
      }
      empresaId = auth.getString('empresa');
    }
    const q = e.requestInfo().query;
    const de = q.de || '0001-01-01';
    const ate = q.ate || '9999-12-31';
    const app = e.app;

    const recs = app.findRecordsByFilter(
      'faturas',
      "empresa = {:e} && estado = 'confirmada' && data_fatura >= {:de} && data_fatura <= {:ate}",
      '-data_fatura',
      0,
      0,
      { e: empresaId, de: de, ate: ate },
    );
    const base = app.settings().meta.appURL || '';

    // Nome canónico para a contabilidade: FT-NOMEFORNECEDOR-DDMMAAAA.ext
    const ACC = {
      Á: 'A', À: 'A', Ã: 'A', Â: 'A', Ä: 'A',
      É: 'E', È: 'E', Ê: 'E', Ë: 'E',
      Í: 'I', Ì: 'I', Î: 'I', Ï: 'I',
      Ó: 'O', Ò: 'O', Õ: 'O', Ô: 'O', Ö: 'O',
      Ú: 'U', Ù: 'U', Û: 'U', Ü: 'U', Ç: 'C',
    };
    const slug = (s) => {
      let out = String(s || '').toUpperCase();
      for (const k in ACC) out = out.split(k).join(ACC[k]);
      out = out.replace(/[^A-Z0-9]/g, '').slice(0, 40);
      return out || 'FORNECEDOR';
    };
    const nomeExport = (f) => {
      const d = String(f.getString('data_fatura') || '').substring(0, 10); // YYYY-MM-DD
      const ddmmaaaa =
        d.length === 10 ? d.slice(8, 10) + d.slice(5, 7) + d.slice(0, 4) : '';
      const fich = f.getString('ficheiro');
      const dot = fich.lastIndexOf('.');
      const ext = dot > -1 ? fich.slice(dot).toLowerCase() : '.pdf';
      return 'FT-' + slug(f.getString('fornecedor')) + '-' + ddmmaaaa + ext;
    };

    const out = [];
    for (const f of recs) {
      const linhas = app.findRecordsByFilter(
        'faturas_itens',
        'fatura = {:f}',
        '',
        0,
        0,
        { f: f.id },
      );
      out.push({
        id: f.id,
        fornecedor: f.getString('fornecedor'),
        dataFatura: f.getString('data_fatura'),
        numero: f.getString('numero'),
        total: f.getFloat('total'),
        iva: f.getFloat('iva'),
        nomeFicheiro: nomeExport(f),
        ficheiroUrl:
          base + '/api/files/faturas/' + f.id + '/' + f.getString('ficheiro'),
        linhas: linhas.map((l) => ({
          descricao: l.getString('descricao_fatura'),
          ingrediente: l.getString('ingrediente'),
          quantidadeG: l.getFloat('quantidade_g'),
          precoUnitario: l.getFloat('preco_unitario'),
          totalLinha: l.getFloat('total_linha'),
          acao: l.getString('acao'),
        })),
      });
    }
    return e.json(200, { faturas: out });
  },
  $apis.requireAuth('users', '_superusers'),
);
