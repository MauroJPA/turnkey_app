/// <reference path="../pb_data/types.d.ts" />

// Fase 5 — análise de faturas por IA (Anthropic) e aplicação aos ingredientes.
//
//   POST /api/gc_turnkey/faturas/{id}/analisar   { imagem(base64), mime }
//   POST /api/gc_turnkey/faturas/{id}/aplicar    { linhas: [...] }
//   POST /api/gc_turnkey/faturas/ignorar-lote    { ids: [...] }
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
    // espaços a mais (duplos, tabs) na marca/fornecedor lidos da fatura só
    // criam variantes novas do mesmo nome — nunca junta nomes diferentes.
    const normEsp = require(`${__hooks}/marcas_fornecedores.js`).normalizarEspacos;
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
    const fornecedorFatura = normEsp(fatura.getString('fornecedor'));

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
    let puladas = 0; // linhas já aplicadas antes (não se tocam outra vez)
    let pendentes = 0;

    e.app.runInTransaction((tx) => {
      // linhas já gravadas antes (por índice) — as marcadas `aplicado` não se
      // voltam a tocar (evita duplicar preços/movimentos ao reaplicar a fatura).
      const antigas = tx.findRecordsByFilter(
        'faturas_itens',
        'fatura = {:f}',
        '',
        0,
        0,
        { f: id },
      );
      const porIndice = {};
      for (const a of antigas) {
        const ix = a.getFloat('linha_index');
        if (ix !== null && ix !== undefined) porIndice[ix] = a;
      }

      for (let li = 0; li < linhas.length; li++) {
        const l = linhas[li];
        const indice = Number.isFinite(Number(l.index)) ? Number(l.index) : li;
        const existente = porIndice[indice];
        if (existente && existente.getBool('aplicado')) {
          puladas++;
          continue;
        }

        const acao = l.acao || 'pendente';
        const ingId = l.ingredienteId || '';
        const consId = l.consumivelId || '';
        const embId = l.embalagemId || '';
        const q = Number(l.quantidadeG || 0);
        const pu = Number(l.precoUnitario || 0);
        const emb = Number(l.embalagemG || 0);

        // O que ficou realmente gravado nesta linha (marca/fornecedor e, para
        // ingredientes, QUAL produto de compra) — guarda-se em `faturas_itens`
        // para dar para corrigir depois (endpoint /corrigir-item), mesmo
        // reabrindo a fatura muito depois de aplicada.
        let produtoTocadoId = '';
        let marcaFinal = '';
        let fornecedorFinal = '';

        // Embalagens (caixas, sacos, adesivos…): preço por peça (sem stock).
        if (acao !== 'ignorar' && acao !== 'pendente' && embId && !ingId && !consId) {
          let embReg = null;
          try {
            embReg = tx.findRecordById('embalagens', String(embId));
            if (embReg.getString('empresa') !== empresaId) embReg = null;
          } catch (_) {
            embReg = null;
          }
          if (embReg) {
            const prods = require(`${__hooks}/produtos.js`);
            const desc = prods.normalizarDescricao(l.descricaoFatura);
            let nomes = [];
            try {
              const v = JSON.parse(embReg.getString('nomes_fatura') || '[]');
              if (Array.isArray(v)) nomes = v;
            } catch (_) {}
            if (desc && nomes.indexOf(desc) === -1) {
              nomes.push(desc);
              while (nomes.length > 50) nomes.shift();
              embReg.set('nomes_fatura', nomes);
            }
            if (!embReg.getString('fornecedor') && fornecedorFatura) {
              embReg.set('fornecedor', fornecedorFatura);
            }
            if (pu > 0 && (acao === 'preco' || acao === 'ambos')) {
              embReg.set('preco_compra', pu);
              embReg.set('unidades_compra', 1);
              precos++;
            }
            tx.save(embReg);
            fornecedorFinal = embReg.getString('fornecedor');
          }
        }

        // Limpeza / insumos: guarda o preço e o nome desta fatura no consumível
        // (sem stock). Os documentos (FDS…) ficam onde estão — a app mostra-os.
        if (acao !== 'ignorar' && acao !== 'pendente' && consId && !ingId) {
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
              cons.set('marca', normEsp(l.marca).substring(0, 200));
            }
            if (!cons.getString('fornecedor') && fornecedorFatura) {
              cons.set('fornecedor', fornecedorFatura);
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
            marcaFinal = cons.getString('marca');
            fornecedorFinal = cons.getString('fornecedor');
          }
        }

        if (acao !== 'ignorar' && acao !== 'pendente' && ingId) {
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
              }
              // Preenche marca/fornecedor sempre que ainda estão em branco —
              // quer o produto seja novo, quer já exista (emparelhado por nome
              // de fatura) mas ainda sem essa informação. Nunca substitui um
              // valor já certo — para isso há o endpoint /corrigir-item.
              if (l.marca && !prod.getString('marca')) {
                prod.set('marca', normEsp(l.marca).substring(0, 200));
              }
              if (!prod.getString('fornecedor') && fornecedorFatura) {
                prod.set('fornecedor', fornecedorFatura);
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
              produtoTocadoId = prod.id;
              marcaFinal = prod.getString('marca');
              fornecedorFinal = prod.getString('fornecedor');
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

        const aplicadaAgora =
          acao !== 'ignorar' && acao !== 'pendente' && (!!ingId || !!consId || !!embId);

        const row = existente || new Record(tx.findCollectionByNameOrId('faturas_itens'));
        row.set('empresa', empresaId);
        row.set('fatura', id);
        row.set('linha_index', indice);
        row.set('ingrediente', ingId || '');
        row.set('consumivel', consId || '');
        row.set('embalagem', embId || '');
        row.set('descricao_fatura', String(l.descricaoFatura || ''));
        row.set('quantidade_g', q);
        row.set('preco_unitario', pu);
        row.set('total_linha', Number(l.totalLinha || 0));
        row.set('embalagem_g', emb);
        row.set('acao', acao);
        row.set('aplicado', aplicadaAgora);
        // Mantém o que já estava gravado se esta ronda não tocou no destino
        // (ex.: reaplicar uma linha "só stock", que não passa pelo produto).
        row.set('produto', produtoTocadoId || row.getString('produto') || '');
        row.set('marca', marcaFinal || row.getString('marca') || '');
        row.set('fornecedor', fornecedorFinal || row.getString('fornecedor') || '');
        tx.save(row);
      }

      // Total de linhas desta fatura (não só as submetidas agora — dá para
      // aplicar por partes) e o que já está resolvido (aplicado ou ignorado),
      // juntando rondas anteriores com esta.
      let totalLinhas = linhas.length;
      try {
        const di = JSON.parse(fatura.getString('dados_ia') || '{}');
        // uma linha acrescentada à mão (item que a IA não leu) pode passar do
        // total original — nesse caso o total sobe com ela.
        if (Array.isArray(di.linhas) && di.linhas.length > 0) {
          totalLinhas = Math.max(di.linhas.length, linhas.length);
        }
      } catch (_) {}
      const todas = tx.findRecordsByFilter('faturas_itens', 'fatura = {:f}', '', 0, 0, { f: id });
      const vistos = {};
      let resolvidas = 0;
      for (const r of todas) {
        const ix = r.getFloat('linha_index');
        if (ix === null || ix === undefined || vistos[ix]) continue;
        vistos[ix] = true;
        if (r.getBool('aplicado') || r.getString('acao') === 'ignorar') resolvidas++;
      }
      pendentes = Math.max(0, totalLinhas - resolvidas);
      fatura.set('pendentes_linhas', pendentes);
      fatura.set('estado', pendentes > 0 ? 'analisada' : 'confirmada');
      tx.save(fatura);
    });

    return e.json(200, {
      precos: precos,
      precosIgnorados: precosIgnorados,
      movimentos: movimentos,
      puladas: puladas,
      pendentes: pendentes,
    });
  },
  $apis.requireAuth('users', '_superusers'),
);

// --- POST /api/gc_turnkey/faturas/ignorar-lote ----------------------------
// Marca várias faturas como `ignorada` de uma vez — para faturas antigas que
// só interessa ter o ficheiro digitalizado, sem ninguém precisar de decidir
// preço/stock linha a linha. Não apaga nada (o ficheiro fica); reabrir a
// fatura e aplicar qualquer linha tira-a sozinha do estado `ignorada` (o
// /aplicar recalcula sempre o estado a partir do que falta decidir).
routerAdd(
  'POST',
  '/api/gc_turnkey/faturas/ignorar-lote',
  (e) => {
    const auth = e.auth;
    const isSuper =
      auth && auth.collection() && auth.collection().name === '_superusers';
    let empresaId = null;
    if (!isSuper) {
      if (!auth || auth.collection().name !== 'users') {
        throw new ForbiddenError('Autenticação necessária.');
      }
      if (auth.getString('papel') === 'viewer') {
        throw new ForbiddenError('Sem permissão.');
      }
      empresaId = auth.getString('empresa');
    }

    const body = e.requestInfo().body || {};
    const ids = Array.isArray(body.ids) ? body.ids : [];
    if (!ids.length) throw new BadRequestError('Escolhe pelo menos uma fatura.');

    let atualizadas = 0;
    e.app.runInTransaction((tx) => {
      for (const id of ids) {
        let f;
        try {
          f = tx.findRecordById('faturas', String(id));
        } catch (_) {
          continue;
        }
        if (!isSuper && f.getString('empresa') !== empresaId) continue;
        if (f.getBool('apagada')) continue;
        if (f.getString('estado') === 'ignorada') continue;
        f.set('estado', 'ignorada');
        f.set('pendentes_linhas', 0);
        tx.save(f);
        atualizadas++;
      }
    });

    return e.json(200, { atualizadas: atualizadas });
  },
  $apis.requireAuth('users', '_superusers'),
);

// --- POST /api/gc_turnkey/faturas/{id}/corrigir-item ---------------------
// Corrige a MARCA que ficou gravada numa linha já aplicada (mesmo com a
// fatura confirmada) — só para o proprietário e o administrador, para o caso
// de algo passar despercebido e só se notar depois, olhando de novo para a
// fatura em PDF/imagem. Ao contrário de /aplicar, esta escrita nunca fica
// bloqueada por `aplicado = true` nem por já haver marca (é uma correção
// explícita: substitui sempre o que estava).
//
// O FORNECEDOR não se corrige aqui: é um só por fatura (todas as linhas são
// do mesmo fornecedor), por isso corrige-se uma única vez no cabeçalho da
// fatura (editar fornecedor) — e essa correção propaga-se sozinha a todos os
// produtos/consumíveis/embalagens já tocados (ver faturas_edicao.pb.js).
routerAdd(
  'POST',
  '/api/gc_turnkey/faturas/{id}/corrigir-item',
  (e) => {
    const normEsp = require(`${__hooks}/marcas_fornecedores.js`).normalizarEspacos;
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
      const papel = auth.getString('papel');
      if (papel !== 'owner' && papel !== 'admin') {
        throw new ForbiddenError('Só o proprietário ou o administrador corrigem uma fatura já aplicada.');
      }
    }

    const body = e.requestInfo().body || {};
    const indice = Number(body.index);
    if (!Number.isFinite(indice)) throw new BadRequestError('Falta o índice da linha.');
    if (!Object.prototype.hasOwnProperty.call(body, 'marca')) {
      throw new BadRequestError('Nada para corrigir.');
    }
    const novaMarca = normEsp(body.marca).substring(0, 200);

    let resultado = null;
    e.app.runInTransaction((tx) => {
      const itens = tx.findRecordsByFilter(
        'faturas_itens',
        'fatura = {:f} && linha_index = {:i}',
        '',
        1,
        0,
        { f: id, i: indice },
      );
      const item = itens[0];
      if (!item) throw new BadRequestError('Essa linha ainda não foi aplicada.');

      const produtoId = item.getString('produto');
      const consId = item.getString('consumivel');
      let alvo = null;
      let colecao = '';
      if (produtoId) {
        colecao = 'ingrediente_produtos';
      } else if (consId) {
        colecao = 'consumiveis';
      } else {
        // embalagens não têm campo `marca` (têm `caracteristica`) — nada a
        // corrigir aqui para uma linha ligada só a uma embalagem.
        throw new BadRequestError('Esta linha não tem marca para corrigir.');
      }
      const alvoId = produtoId || consId;
      try {
        alvo = tx.findRecordById(colecao, alvoId);
      } catch (_) {
        alvo = null;
      }
      if (!alvo || alvo.getString('empresa') !== empresaId) {
        throw new BadRequestError('O registo ligado a esta linha já não existe.');
      }

      const antesMarca = alvo.getString('marca');
      alvo.set('marca', novaMarca);
      tx.save(alvo);

      item.set('marca', novaMarca);
      tx.save(item);

      try {
        const quem = auth
          ? auth.getString('nome') || auth.getString('email') || auth.id
          : '';
        const h = new Record(e.app.findCollectionByNameOrId('historico'));
        h.set('empresa', empresaId);
        h.set('entidade_tipo', 'fatura');
        h.set('entidade_id', id);
        h.set(
          'descricao',
          (
            'Fatura — linha "' + item.getString('descricao_fatura') + '" corrigida: ' +
            'marca: "' + antesMarca + '" → "' + novaMarca + '"' + (quem ? ' (por ' + quem + ')' : '')
          ).substring(0, 500),
        );
        h.set('valor_antes', { marca: antesMarca });
        h.set('valor_depois', { marca: novaMarca });
        if (auth && auth.collection().name === 'users') h.set('autor', auth.id);
        tx.save(h);
      } catch (err) {
        console.log('[faturas.corrigir-item] historico: ' + err);
      }

      resultado = { marca: item.getString('marca') };
    });

    return e.json(200, { ok: true, marca: resultado.marca });
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
      "empresa = {:e} && estado = 'confirmada' && apagada != true && data_fatura >= {:de} && data_fatura <= {:ate}",
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
