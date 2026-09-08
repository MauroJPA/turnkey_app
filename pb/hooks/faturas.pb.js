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

    const key = $os.getenv('ANTHROPIC_API_KEY');
    if (!key) {
      throw new ApiError(503, 'IA não configurada (falta ANTHROPIC_API_KEY).', null);
    }
    const model = $os.getenv('TURNKEY_AI_MODEL') || 'claude-sonnet-5';

    const body = e.requestInfo().body || {};
    const imagem = (body.imagem || '').toString();
    let mime = (body.mime || 'image/jpeg').toString();
    if (!imagem) throw new BadRequestError('Falta a imagem (base64).');
    const bloco =
      mime === 'application/pdf'
        ? { type: 'document', source: { type: 'base64', media_type: mime, data: imagem } }
        : { type: 'image', source: { type: 'base64', media_type: mime, data: imagem } };

    const tipo = fatura.getString('tipo') || 'fatura';
    const isLista = tipo === 'lista_precos';
    const sistema =
      'És um extrator de dados de ' +
      (isLista ? 'listas de preços' : 'faturas de compra') +
      ' de uma padaria em Portugal. Responde APENAS com JSON válido, sem texto ' +
      'à volta e sem cercas de código. Formato: {"fornecedor": string, "data": ' +
      '"YYYY-MM-DD"|null, "numero": string|null, "total": number|null, "iva": ' +
      'number|null, "moeda": string|null, "linhas": [{"descricao": string, ' +
      '"quantidade": number|null, "unidade": string|null, "preco_unitario": ' +
      'number|null, "total": number|null, "embalagem_g": number|null}]}. ' +
      'Regras: preco_unitario é o preço por unidade/embalagem, NÃO o total da ' +
      'linha. Não incluas descontos, portes ou totais como linhas de produto. ' +
      'embalagem_g só quando o peso/volume da embalagem aparecer (converte kg->g, ' +
      'L->ml tratado como g). ' +
      (isLista ? 'Numa lista de preços, quantidade e total são null.' : '');

    const payload = {
      model: model,
      max_tokens: 2000,
      system: sistema,
      messages: [
        {
          role: 'user',
          content: [
            bloco,
            { type: 'text', text: 'Extrai os dados. Só JSON.' },
          ],
        },
      ],
    };

    let resp;
    try {
      resp = $http.send({
        url: 'https://api.anthropic.com/v1/messages',
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-api-key': key,
          'anthropic-version': '2023-06-01',
        },
        body: JSON.stringify(payload),
        timeout: 120,
      });
    } catch (err) {
      fatura.set('estado', 'erro');
      fatura.set('dados_ia', { erro: 'Falha de rede: ' + err });
      e.app.save(fatura);
      throw new ApiError(502, 'Não foi possível contactar a IA.', null);
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      const detalhe =
        resp.json && resp.json.error
          ? resp.json.error.message
          : 'HTTP ' + resp.statusCode;
      fatura.set('estado', 'erro');
      fatura.set('dados_ia', { erro: detalhe });
      e.app.save(fatura);
      throw new ApiError(502, 'A IA respondeu com erro: ' + detalhe, null);
    }

    let texto = '';
    try {
      const parts = resp.json.content || [];
      for (const p of parts) if (p.type === 'text') texto += p.text;
    } catch (_) {}
    texto = texto.trim();
    // tolerar cercas ```json ... ```
    const m = texto.match(/```(?:json)?\s*([\s\S]*?)```/);
    if (m) texto = m[1].trim();

    let dados;
    try {
      dados = JSON.parse(texto);
    } catch (_) {
      fatura.set('estado', 'erro');
      fatura.set('dados_ia', { erro: 'Resposta não é JSON', bruto: texto });
      e.app.save(fatura);
      throw new ApiError(502, 'A IA não devolveu JSON válido.', null);
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

    return e.json(200, { estado: 'analisada', dados: dados });
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
