/// <reference path="../pb_data/types.d.ts" />

// Fase 2 — endpoints de stock e produção.
// (handlers autocontidos; lógica pesada em cascade.js via require())
//
//   POST /api/turnkey/inventario/ajustar          { ingrediente?|ficha?, delta, motivo, notas?, producao? }
//   GET  /api/turnkey/producoes/{id}/plano
//   POST /api/turnkey/producoes/{id}/lista-compras
//   POST /api/turnkey/producoes/{id}/concluir

// --- POST /api/turnkey/inventario/ajustar ---------------------------------
routerAdd(
  'POST',
  '/api/turnkey/inventario/ajustar',
  (e) => {
    const auth = e.auth;
    const isSuper =
      auth && auth.collection() && auth.collection().name === '_superusers';
    const body = e.requestInfo().body || {};
    let empresaId = body.empresa || '';
    let autorId = null;

    if (!isSuper) {
      if (!auth || auth.collection().name !== 'users') {
        throw new ForbiddenError('Autenticação necessária.');
      }
      if (auth.getString('papel') === 'viewer') {
        throw new ForbiddenError('Sem permissão.');
      }
      empresaId = auth.getString('empresa');
      autorId = auth.id;
    }
    if (!empresaId) throw new BadRequestError('empresa em falta.');

    if (!body.ingrediente && !body.ficha) {
      throw new BadRequestError('Indica ingrediente ou ficha.');
    }
    const delta = Number(body.delta || 0);
    const temMeta =
      body.minimo !== undefined || body.localizacao !== undefined;
    if ((!isFinite(delta) || delta === 0) && !temMeta) {
      throw new BadRequestError('Nada para alterar.');
    }
    const motivo = body.motivo || 'ajuste';
    const alvoCampo = body.ingrediente ? 'ingrediente' : 'ficha';
    const alvoId = body.ingrediente || body.ficha;

    let quantidade = 0;
    e.app.runInTransaction((tx) => {
      if (delta !== 0 && isFinite(delta)) {
        quantidade = require(`${__hooks}/cascade.js`).aplicarMovimento(
          tx,
          {
            empresaId: empresaId,
            ingredienteId: body.ingrediente || null,
            fichaId: body.ficha || null,
          },
          delta,
          motivo,
          { autorId: autorId, notas: body.notas, producaoId: body.producao },
        );
      }
      if (temMeta) {
        const achados = tx.findRecordsByFilter(
          'inventario',
          'empresa = {:e} && ' + alvoCampo + ' = {:i}',
          '',
          1,
          0,
          { e: empresaId, i: alvoId },
        );
        let row;
        if (achados.length > 0) {
          row = achados[0];
        } else {
          row = new Record(tx.findCollectionByNameOrId('inventario'));
          row.set('empresa', empresaId);
          row.set(alvoCampo, alvoId);
          row.set('quantidade', 0);
        }
        if (body.minimo !== undefined) row.set('minimo', Number(body.minimo));
        if (body.localizacao !== undefined) {
          row.set('localizacao', String(body.localizacao));
        }
        tx.save(row);
        quantidade = row.getFloat('quantidade');
      }
    });

    return e.json(200, { quantidade: quantidade });
  },
  $apis.requireAuth('users', '_superusers'),
);

// --- GET /api/turnkey/producoes/{id}/plano -------------------------------
routerAdd(
  'GET',
  '/api/turnkey/producoes/{id}/plano',
  (e) => {
    const cascade = require(`${__hooks}/cascade.js`);
    const ctx = require(`${__hooks}/cascade.js`).carregarProducao(e, false);
    const app = e.app;
    const num = (rec, f) => {
      try {
        return rec.getFloat(f);
      } catch (_) {
        return 0;
      }
    };

    // explosão agregada -> necessarios
    const agg = {};
    for (const it of ctx.itens) {
      const alvoG = num(it, 'quantidade_kg') * 1000;
      const parcial = cascade.explodeCompras(app, it.getString('receita'), alvoG);
      for (const k in parcial) agg[k] = (agg[k] || 0) + parcial[k];
    }

    const necessarios = [];
    let custoTotal = 0;
    for (const ingId in agg) {
      let ing;
      try {
        ing = app.findRecordById('ingredientes', ingId);
      } catch (_) {
        continue;
      }
      const g = agg[ingId];
      const gramasEmb = num(ing, 'gramas_embalagem');
      const cpg = gramasEmb > 0 ? num(ing, 'preco') / gramasEmb : 0;
      const custo = cpg * g;
      custoTotal += custo;

      let emStock = 0;
      const inv = app.findRecordsByFilter(
        'inventario',
        'empresa = {:e} && ingrediente = {:i}',
        '',
        1,
        0,
        { e: ctx.empresaId, i: ingId },
      );
      if (inv.length > 0) emStock = inv[0].getFloat('quantidade');

      necessarios.push({
        ingredienteId: ingId,
        nome: ing.getString('nome'),
        fornecedor: ing.getString('fornecedor'),
        gramas: g,
        custo: custo,
        emStock: emStock,
        aComprar: Math.max(0, g - emStock),
      });
    }
    necessarios.sort((a, b) => a.nome.localeCompare(b.nome));

    // o que se produz
    const produzir = [];
    for (const it of ctx.itens) {
      let r;
      try {
        r = app.findRecordById('receitas', it.getString('receita'));
      } catch (_) {
        continue;
      }
      produzir.push({
        receitaId: r.id,
        nome: r.getString('nome'),
        kg: num(it, 'quantidade_kg'),
      });
    }

    return e.json(200, {
      necessarios: necessarios,
      produzir: produzir,
      custoTotal: custoTotal,
    });
  },
  $apis.requireAuth('users', '_superusers'),
);

// --- POST /api/turnkey/producoes/{id}/lista-compras --------------------
routerAdd(
  'POST',
  '/api/turnkey/producoes/{id}/lista-compras',
  (e) => {
    const cascade = require(`${__hooks}/cascade.js`);
    const ctx = require(`${__hooks}/cascade.js`).carregarProducao(e, true);
    const app = e.app;
    const num = (rec, f) => {
      try {
        return rec.getFloat(f);
      } catch (_) {
        return 0;
      }
    };

    const agg = {};
    for (const it of ctx.itens) {
      const alvoG = num(it, 'quantidade_kg') * 1000;
      const parcial = cascade.explodeCompras(app, it.getString('receita'), alvoG);
      for (const k in parcial) agg[k] = (agg[k] || 0) + parcial[k];
    }

    let linhas = 0;
    app.runInTransaction((tx) => {
      for (const ingId in agg) {
        let ing;
        try {
          ing = tx.findRecordById('ingredientes', ingId);
        } catch (_) {
          continue;
        }
        const necessario = agg[ingId];

        let emStock = 0;
        const inv = tx.findRecordsByFilter(
          'inventario',
          'empresa = {:e} && ingrediente = {:i}',
          '',
          1,
          0,
          { e: ctx.empresaId, i: ingId },
        );
        if (inv.length > 0) emStock = inv[0].getFloat('quantidade');
        const comprar = Math.max(0, necessario - emStock);

        const existentes = tx.findRecordsByFilter(
          'lista_compras',
          'empresa = {:e} && ingrediente = {:i} && comprado = false && producao = {:p}',
          '',
          1,
          0,
          { e: ctx.empresaId, i: ingId, p: ctx.producao.id },
        );
        let row;
        if (existentes.length > 0) {
          row = existentes[0];
        } else {
          row = new Record(tx.findCollectionByNameOrId('lista_compras'));
          row.set('empresa', ctx.empresaId);
          row.set('ingrediente', ingId);
          row.set('producao', ctx.producao.id);
          row.set('comprado', false);
        }
        row.set('descricao', ing.getString('nome'));
        row.set('fornecedor', ing.getString('fornecedor'));
        row.set('quantidade_necessaria_g', necessario);
        row.set('quantidade_comprar_g', comprar);
        tx.save(row);
        linhas++;
      }
    });

    return e.json(200, { linhas: linhas });
  },
  $apis.requireAuth('users', '_superusers'),
);

// --- POST /api/turnkey/producoes/{id}/concluir ------------------------
routerAdd(
  'POST',
  '/api/turnkey/producoes/{id}/concluir',
  (e) => {
    const cascade = require(`${__hooks}/cascade.js`);
    const ctx = require(`${__hooks}/cascade.js`).carregarProducao(e, true);
    const app = e.app;
    const num = (rec, f) => {
      try {
        return rec.getFloat(f);
      } catch (_) {
        return 0;
      }
    };

    if (ctx.producao.getString('estado') === 'concluida') {
      throw new BadRequestError('Esta produção já está concluída.');
    }

    const consumos = [];
    const saidas = [];
    const faltas = [];
    let custoTotal = 0;

    app.runInTransaction((tx) => {
      const espelhoDe = (receitaId) => {
        const r = tx.findRecordsByFilter(
          'ingredientes',
          'empresa = {:e} && receita_espelho = {:r}',
          '',
          1,
          0,
          { e: ctx.empresaId, r: receitaId },
        );
        return r.length > 0 ? r[0] : null;
      };
      const consumir = (ingRec, g, nome) => {
        cascade.aplicarMovimento(
          tx,
          { empresaId: ctx.empresaId, ingredienteId: ingRec.id },
          -g,
          'consumo_producao',
          { autorId: ctx.autorId, producaoId: ctx.producao.id },
        );
        const gramasEmb = num(ingRec, 'gramas_embalagem');
        const cpg = gramasEmb > 0 ? num(ingRec, 'preco') / gramasEmb : 0;
        custoTotal += cpg * g;
        consumos.push({ nome: nome || ingRec.getString('nome'), gramas: g });
      };

      for (const it of ctx.itens) {
        const receitaId = it.getString('receita');
        let receita;
        try {
          receita = tx.findRecordById('receitas', receitaId);
        } catch (_) {
          continue;
        }
        const alvoG = num(it, 'quantidade_kg') * 1000;
        const rend = num(receita, 'rendimento_esperado');
        const fator = rend > 0 ? alvoG / rend : 0;

        const linhas = tx.findRecordsByFilter(
          'itens_receita',
          'receita = {:id}',
          '',
          0,
          0,
          { id: receitaId },
        );
        for (const l of linhas) {
          const g = num(l, 'quantidade_g') * fator;
          if (g <= 0) continue;
          const subRel = l.getString('sub_receita');
          const ingRel = l.getString('ingrediente');
          if (subRel) {
            const esp = espelhoDe(subRel);
            if (esp) {
              consumir(esp, g, esp.getString('nome'));
            } else {
              faltas.push('Sub-receita sem stock: ' + l.getString('nome_provisorio'));
            }
          } else if (ingRel) {
            let ing;
            try {
              ing = tx.findRecordById('ingredientes', ingRel);
            } catch (_) {
              continue;
            }
            consumir(ing, g, ing.getString('nome'));
          }
        }

        // saída: +alvoG g no ingrediente-espelho da receita
        const esp = espelhoDe(receitaId);
        if (esp) {
          cascade.aplicarMovimento(
            tx,
            { empresaId: ctx.empresaId, ingredienteId: esp.id },
            alvoG,
            'saida_producao',
            { autorId: ctx.autorId, producaoId: ctx.producao.id },
          );
          saidas.push({ nome: receita.getString('nome'), gramas: alvoG });
        } else {
          faltas.push(
            receita.getString('nome') +
              ' não está publicada como ingrediente — produto não entrou em stock.',
          );
        }
      }

      ctx.producao.set('estado', 'concluida');
      ctx.producao.set('concluida_em', new Date().toISOString().slice(0, 10));
      ctx.producao.set('custo_snapshot', custoTotal);
      tx.save(ctx.producao);
    });

    return e.json(200, {
      consumos: consumos,
      saidas: saidas,
      faltas: faltas,
      custoTotal: custoTotal,
    });
  },
  $apis.requireAuth('users', '_superusers'),
);
