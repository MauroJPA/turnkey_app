/// <reference path="../pb_data/types.d.ts" />

// Fase 5 — análise de faturas por IA (Anthropic) e aplicação aos ingredientes.
//
//   POST /api/turnkey/faturas/{id}/analisar   { imagem(base64), mime }
//   POST /api/turnkey/faturas/{id}/aplicar    { linhas: [...] }
//   GET  /api/turnkey/faturas/export?de=&ate=
//
// A chave da IA vem de ANTHROPIC_API_KEY no ambiente do servidor. Nunca no app.

// --- POST /api/turnkey/faturas/{id}/analisar --------------------------
routerAdd(
  'POST',
  '/api/turnkey/faturas/{id}/analisar',
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
    const imagem = (body.imagem || '').toString();
    const mime = (body.mime || 'image/jpeg').toString();
    if (!imagem) throw new BadRequestError('Falta a imagem (base64).');

    const tipo = fatura.getString('tipo') || 'fatura';
    const isLista = tipo === 'lista_precos';

    // Análise por IA — fornecedor selecionável por TURNKEY_AI_PROVIDER
    // (gemini por omissão; anthropic disponível). Ver pb/hooks/ai.js.
    const ai = require(`${__hooks}/ai.js`);
    const r = ai.analisarFaturaIA({
      imagemBase64: imagem,
      mime: mime,
      isLista: isLista,
    });

    if (!r.ok) {
      // 503 = problema de configuração do servidor: não marca a fatura.
      if (r.code === 503) throw new ApiError(503, r.message, null);
      fatura.set('estado', 'erro');
      fatura.set(
        'dados_ia',
        r.raw ? { erro: r.message, bruto: r.raw } : { erro: r.message },
      );
      e.app.save(fatura);
      throw new ApiError(502, r.message, null);
    }

    const dados = r.dados;

    // --- deteção de fatura duplicada (não se aplica a listas de preços) -----
    if (!isLista) {
      const forn = String(dados.fornecedor || fatura.getString('fornecedor') || '');
      const num = String(dados.numero || fatura.getString('numero') || '');
      const dataF = String(dados.data || fatura.getString('data_fatura') || '').substring(0, 10);
      const totalF =
        typeof dados.total === 'number' ? dados.total : fatura.getFloat('total');
      const norm = (s) =>
        String(s || '').toLowerCase().replace(/\s+/g, '').replace(/[^a-z0-9]/g, '');
      const fN = norm(forn);
      if (fN && (norm(num) || dataF)) {
        const candidatos = e.app.findRecordsByFilter(
          'faturas',
          "empresa = {:e} && id != {:id} && tipo = 'fatura' && estado != 'erro'",
          '',
          200,
          0,
          { e: empresaId, id: id },
        );
        let dup = null;
        for (const c of candidatos) {
          if (norm(c.getString('fornecedor')) !== fN) continue;
          const cData = String(c.getString('data_fatura') || '').substring(0, 10);
          if (norm(num)) {
            if (norm(c.getString('numero')) === norm(num) &&
                (!dataF || !cData || cData === dataF)) {
              dup = c;
              break;
            }
          } else if (dataF && cData === dataF && totalF > 0 &&
                     Math.abs(c.getFloat('total') - totalF) < 0.01) {
            dup = c;
            break;
          }
        }
        if (dup) {
          fatura.set('estado', 'erro');
          fatura.set('dados_ia', {
            erro:
              'Fatura duplicada: ja existe "' +
              (num || dataF) +
              '" de ' +
              forn +
              '.',
            duplicada_de: dup.id,
            linhas: dados.linhas || [],
          });
          e.app.save(fatura);
          throw new ApiError(
            409,
            'Fatura duplicada de ' + forn + ' (' + (num || dataF) + ').',
            null,
          );
        }
      }
    }

    fatura.set('dados_ia', dados);
    fatura.set('estado', 'analisada');
    if (!fatura.getString('fornecedor') && dados.fornecedor)
      fatura.set('fornecedor', String(dados.fornecedor));
    if (!fatura.getString('numero') && dados.numero)
      fatura.set('numero', String(dados.numero));
    if (!fatura.get('total') && typeof dados.total === 'number')
      fatura.set('total', dados.total);
    if (!fatura.get('iva') && typeof dados.iva === 'number')
      fatura.set('iva', dados.iva);
    if (!fatura.getString('data_fatura') && dados.data)
      fatura.set('data_fatura', String(dados.data));
    e.app.save(fatura);

    return e.json(200, { estado: 'analisada', provider: r.provider, dados: dados });
  },
  $apis.requireAuth('users', '_superusers'),
);

// --- POST /api/turnkey/faturas/{id}/aplicar --------------------------
routerAdd(
  'POST',
  '/api/turnkey/faturas/{id}/aplicar',
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

    let precos = 0;
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
        const q = Number(l.quantidadeG || 0);
        const pu = Number(l.precoUnitario || 0);
        const emb = Number(l.embalagemG || 0);

        if (acao !== 'ignorar' && ingId) {
          if (acao === 'preco' || acao === 'ambos') {
            let ing;
            try {
              ing = tx.findRecordById('ingredientes', ingId);
            } catch (_) {
              ing = null;
            }
            if (ing && pu > 0) {
              ing.set('preco', pu);
              if (emb > 0) ing.set('gramas_embalagem', emb);
              ing.set('preco_atualizado_em', new Date().toISOString());
              tx.save(ing);
              precos++;
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
        row.set('descricao_fatura', String(l.descricaoFatura || ''));
        row.set('quantidade_g', q);
        row.set('preco_unitario', pu);
        row.set('total_linha', Number(l.totalLinha || 0));
        row.set('embalagem_g', emb);
        row.set('acao', acao);
        row.set('aplicado', acao !== 'ignorar' && !!ingId);
        tx.save(row);
      }

      fatura.set('estado', 'confirmada');
      tx.save(fatura);
    });

    return e.json(200, { precos: precos, movimentos: movimentos });
  },
  $apis.requireAuth('users', '_superusers'),
);

// --- GET /api/turnkey/faturas/export?de=&ate= ------------------------
routerAdd(
  'GET',
  '/api/turnkey/faturas/export',
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
