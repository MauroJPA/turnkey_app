/// <reference path="../pb_data/types.d.ts" />

// IA no Financeiro — só leitura/sugestões, não grava nada (a pessoa decide):
//
//   POST /api/gc_turnkey/financeiro/classificar-custos
//     -> { provider, sugestoes: [{ id, nome, valorMensal, tipoAtual,
//          tipoSugerido, motivo, acao, dica }] }
//     Organiza os custos ativos da empresa em fixos / variáveis.
//
//   POST /api/gc_turnkey/financeiro/dicas   { periodo, atual, anterior?, custos?,
//                                             percentuais? }
//     -> { provider, resumo, dicas: [{ titulo, texto, prioridade, area }] }
//     Dicas para melhorar, geradas a partir dos números do painel.
//
// Só owner/admin (os custos também só são visíveis para eles).

routerAdd(
  'POST',
  '/api/gc_turnkey/financeiro/classificar-custos',
  (e) => {
    const exigir = (ev) => {
      const auth = ev.auth;
      const isSuper =
        auth && auth.collection() && auth.collection().name === '_superusers';
      if (isSuper) return (ev.requestInfo().body || {}).empresa || '';
      if (!auth || auth.collection().name !== 'users') {
        throw new ForbiddenError('Autenticação necessária.');
      }
      const papel = auth.getString('papel');
      if (papel !== 'owner' && papel !== 'admin') {
        throw new ForbiddenError('Precisas de ser administrador.');
      }
      return auth.getString('empresa');
    };
    const empresaId = exigir(e);
    if (!empresaId) throw new BadRequestError('empresa em falta.');

    const recs = e.app.findRecordsByFilter(
      'custos_fixos',
      'empresa = {:e} && arquivado != true',
      'nome',
      0,
      0,
      { e: empresaId },
    );
    if (recs.length === 0) {
      throw new BadRequestError('Ainda não há custos registados para organizar.');
    }
    const custos = recs.map((r) => ({
      id: r.id,
      nome: r.getString('nome'),
      tipo: r.getString('tipo') === 'variavel' ? 'variavel' : 'fixo',
      valor_mensal: r.getFloat('valor_mensal'),
      notas: r.getString('notas'),
    }));

    const fin = require(`${__hooks}/financeiro_ia.js`);
    const pedido = fin.pedidoClassificar(custos);
    const r = require(`${__hooks}/ai.js`).gerarJsonIA(pedido);
    if (!r.ok) {
      if (r.code === 503) throw new ApiError(503, r.message, null);
      throw new ApiError(502, r.message, null);
    }
    const sugestoes = fin.limparSugestoes(r.dados, custos);
    if (sugestoes.length === 0) {
      throw new ApiError(502, 'A IA não devolveu sugestões utilizáveis. Tenta de novo.', null);
    }
    return e.json(200, { provider: r.provider, sugestoes: sugestoes });
  },
  $apis.requireAuth('users', '_superusers'),
);

routerAdd(
  'POST',
  '/api/gc_turnkey/financeiro/dicas',
  (e) => {
    const auth = e.auth;
    const isSuper =
      auth && auth.collection() && auth.collection().name === '_superusers';
    if (!isSuper) {
      if (!auth || auth.collection().name !== 'users') {
        throw new ForbiddenError('Autenticação necessária.');
      }
      const papel = auth.getString('papel');
      if (papel !== 'owner' && papel !== 'admin') {
        throw new ForbiddenError('Precisas de ser administrador.');
      }
    }

    const body = e.requestInfo().body || {};
    const num = (v) => {
      const n = Number(v);
      return isFinite(n) ? Math.round(n * 100) / 100 : 0;
    };
    const txt = (v, max) => String(v === undefined || v === null ? '' : v).substring(0, max);
    const bloco = (b) => {
      if (!b || typeof b !== 'object') return null;
      return {
        receita: num(b.receita),
        custoProdutos: num(b.custoProdutos),
        custosFixos: num(b.custosFixos),
        custosVariaveis: num(b.custosVariaveis),
        depreciacao: num(b.depreciacao),
        lucroLiquido: num(b.lucroLiquido),
        margemLiquidaPercent: num(b.margemLiquidaPercent),
        numVendas: Math.round(num(b.numVendas)),
        linhasSemProduto: Math.round(num(b.linhasSemProduto)),
      };
    };
    const atual = bloco(body.atual);
    if (!atual) throw new BadRequestError('Faltam os números do período.');
    const p = body.periodo && typeof body.periodo === 'object' ? body.periodo : {};
    const custosIn = Array.isArray(body.custos) ? body.custos.slice(0, 40) : [];
    const custos = [];
    for (const c of custosIn) {
      if (!c || typeof c !== 'object') continue;
      custos.push({
        nome: txt(c.nome, 80),
        tipo: c.tipo === 'variavel' ? 'variavel' : 'fixo',
        valorMensal: num(c.valorMensal),
      });
    }
    const perc = body.percentuais && typeof body.percentuais === 'object' ? body.percentuais : {};
    const resumo = {
      periodo: { nome: txt(p.label, 60), desde: txt(p.desde, 10), ate: txt(p.ate, 10) },
      atual: atual,
      anterior: bloco(body.anterior),
      custosMensais: custos,
      percentuaisConfigurados: { imposto: num(perc.imposto), cmv: num(perc.cmv) },
    };

    const fin = require(`${__hooks}/financeiro_ia.js`);
    const r = require(`${__hooks}/ai.js`).gerarJsonIA(fin.pedidoDicas(resumo));
    if (!r.ok) {
      if (r.code === 503) throw new ApiError(503, r.message, null);
      throw new ApiError(502, r.message, null);
    }
    const limpo = fin.limparDicas(r.dados);
    if (limpo.dicas.length === 0) {
      throw new ApiError(502, 'A IA não devolveu dicas utilizáveis. Tenta de novo.', null);
    }
    return e.json(200, {
      provider: r.provider,
      resumo: limpo.resumo,
      dicas: limpo.dicas,
    });
  },
  $apis.requireAuth('users', '_superusers'),
);
