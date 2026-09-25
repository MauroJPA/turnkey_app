/// <reference path="../pb_data/types.d.ts" />

// Fase 2 — endpoints de stock e produção.
// (handlers autocontidos; lógica pesada em cascade.js via require())
//
//   POST /api/gc_turnkey/inventario/ajustar          { ingrediente?|ficha?, delta, motivo, notas?, producao? }
//   GET  /api/gc_turnkey/producoes/{id}/plano
//   POST /api/gc_turnkey/producoes/{id}/lista-compras
//   POST /api/gc_turnkey/producoes/{id}/concluir

// --- POST /api/gc_turnkey/inventario/ajustar ---------------------------------
routerAdd(
  'POST',
  '/api/gc_turnkey/inventario/ajustar',
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

    const descricaoLivre = (body.descricao || '').toString().trim();
    if (!body.ingrediente && !body.ficha && !descricaoLivre) {
      throw new BadRequestError('Indica ingrediente, ficha ou descrição.');
    }
    const delta = Number(body.delta || 0);
    const temMeta =
      body.minimo !== undefined ||
      body.localizacao !== undefined ||
      body.unidade !== undefined ||
      body.categoria !== undefined ||
      body.favorito !== undefined;
    if ((!isFinite(delta) || delta === 0) && !temMeta) {
      throw new BadRequestError('Nada para alterar.');
    }
    const motivo = body.motivo || 'ajuste';
    const alvoCampo = body.ingrediente
      ? 'ingrediente'
      : body.ficha
        ? 'ficha'
        : 'descricao';
    const alvoId = body.ingrediente || body.ficha || descricaoLivre;

    let quantidade = 0;
    e.app.runInTransaction((tx) => {
      if (delta !== 0 && isFinite(delta)) {
        quantidade = require(`${__hooks}/cascade.js`).aplicarMovimento(
          tx,
          {
            empresaId: empresaId,
            ingredienteId: body.ingrediente || null,
            fichaId: body.ficha || null,
            descricao: descricaoLivre || null,
            unidade: body.unidade || null,
            categoria: body.categoria || null,
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
        if (body.unidade !== undefined) {
          row.set('unidade', String(body.unidade));
        }
        if (body.categoria !== undefined) {
          row.set('categoria', String(body.categoria));
        }
        if (body.favorito !== undefined) {
          row.set('favorito', !!body.favorito);
        }
        tx.save(row);
        quantidade = row.getFloat('quantidade');
      }
    });

    return e.json(200, { quantidade: quantidade });
  },
  $apis.requireAuth('users', '_superusers'),
);

// --- GET /api/gc_turnkey/producoes/{id}/plano -------------------------------
routerAdd(
  'GET',
  '/api/gc_turnkey/producoes/{id}/plano',
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

    // formato de um item: { massaG, recheioG, unidades } ou null
    const infoFormato = (it, alvoG) => {
      const fId = it.getString('formato');
      if (!fId) return null;
      let f;
      try {
        f = app.findRecordById('formatos_cookie', fId);
      } catch (_) {
        return null;
      }
      const massaG = num(f, 'massa_g');
      const recheioG = num(f, 'recheio_g');
      const unidades = massaG > 0 ? Math.round(alvoG / massaG) : 0;
      return {
        nome: f.getString('nome'),
        massaG: massaG,
        recheioG: recheioG,
        unidades: unidades,
      };
    };

    const nomeReceita = (id) => {
      try {
        return app.findRecordById('receitas', id).getString('nome');
      } catch (_) {
        return '';
      }
    };
    const merge = (dst, src) => {
      for (const k in src) dst[k] = (dst[k] || 0) + src[k];
    };

    // Para cada item: o que comprar (ingredientes) e os intermédios a produzir.
    const agg = {};
    const porReceita = [];
    for (const it of ctx.itens) {
      const receitaId = it.getString('receita');
      const alvoG = num(it, 'quantidade_kg') * 1000;
      let fmt = infoFormato(it, alvoG);
      const recheioId = it.getString('recheio');

      // Produto final escolhido (ficha técnica): manda sobre o formato.
      const fichaExp = it.getString('ficha');
      let fichaNomeExp = '';
      if (fichaExp) {
        const fx = cascade.infoFicha(app, fichaExp, alvoG);
        if (fx) {
          fichaNomeExp = fx.nome;
          fmt = {
            nome: fx.formatoNome,
            massaG: fx.massaG,
            recheioG: 0,
            unidades: fx.unidades,
          };
        }
      }

      const ep = cascade.explodeProducao(app, receitaId, alvoG);
      const comprarItem = {};
      const intermediosItem = {};
      merge(comprarItem, ep.comprar);
      merge(intermediosItem, ep.produzir);

      if (fmt && fmt.unidades > 0) {
        const fichaId =
          fichaExp ||
          cascade.resolverFicha(
            app,
            ctx.empresaId,
            receitaId,
            recheioId || '',
            it.getString('formato'),
          );
        if (fichaId) {
          const slots = app.findRecordsByFilter(
            'itens_ficha',
            "ficha = {:f} && slot != 'massa'",
            '',
            0,
            0,
            { f: fichaId },
          );
          for (const sl of slots) {
            const g = num(sl, 'quantidade_g') * fmt.unidades;
            if (g <= 0) continue;
            const recSlot = sl.getString('receita');
            const ingSlot = sl.getString('ingrediente');
            merge(
              comprarItem,
              cascade.explodeComprasDe(app, g, recSlot, ingSlot),
            );
            if (recSlot) intermediosItem[recSlot] = (intermediosItem[recSlot] || 0) + g;
            else if (ingSlot) {
              let ig;
              try {
                ig = app.findRecordById('ingredientes', ingSlot);
              } catch (_) {
                ig = null;
              }
              const esp = ig ? ig.getString('receita_espelho') : '';
              if (ig && ig.getString('origem') === 'fabrico_proprio' && esp) {
                intermediosItem[esp] = (intermediosItem[esp] || 0) + g;
              }
            }
          }
        } else if (recheioId && fmt.recheioG > 0) {
          const gRecheio = fmt.unidades * fmt.recheioG;
          merge(comprarItem, cascade.explodeCompras(app, recheioId, gRecheio));
          intermediosItem[recheioId] =
            (intermediosItem[recheioId] || 0) + gRecheio;
        }
      }

      merge(agg, comprarItem);

      const comprarLista = [];
      for (const k in comprarItem) {
        let ing;
        try {
          ing = app.findRecordById('ingredientes', k);
        } catch (_) {
          continue;
        }
        comprarLista.push({
          ingredienteId: k,
          nome: ing.getString('nome'),
          gramas: comprarItem[k],
        });
      }
      comprarLista.sort((a, b) => a.nome.localeCompare(b.nome));

      const intermediosLista = [];
      for (const k in intermediosItem) {
        intermediosLista.push({
          receitaId: k,
          nome: nomeReceita(k),
          gramas: intermediosItem[k],
        });
      }
      intermediosLista.sort((a, b) => a.nome.localeCompare(b.nome));

      let recheioNome = '';
      if (recheioId) recheioNome = nomeReceita(recheioId);

      porReceita.push({
        receitaId: receitaId,
        fichaId: fichaExp,
        nome: fichaNomeExp || nomeReceita(receitaId),
        kg: num(it, 'quantidade_kg'),
        unidades: fmt ? fmt.unidades : num(it, 'unidades_previstas'),
        formato: fmt ? fmt.nome : '',
        recheio: recheioNome,
        prioridade: it.getString('prioridade') || 'media',
        horaLimite: it.getString('hora_limite'),
        comprar: comprarLista,
        intermedios: intermediosLista,
      });
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

      const faltaG = Math.max(0, g - emStock);
      necessarios.push({
        ingredienteId: ingId,
        nome: ing.getString('nome'),
        fornecedor: ing.getString('fornecedor'),
        gramas: g,
        custo: custo,
        emStock: emStock,
        aComprar: faltaG,
        embalagemG: gramasEmb,
        aComprarSacos:
          gramasEmb > 0 ? Math.ceil(faltaG / gramasEmb) : 0,
      });
    }
    necessarios.sort((a, b) => a.nome.localeCompare(b.nome));

    // `produzir` — projeção compacta de `porReceita` (compatibilidade).
    const produzir = porReceita.map((p) => ({
      receitaId: p.receitaId,
      nome: p.nome,
      kg: p.kg,
      unidades: p.unidades,
      formato: p.formato,
      recheio: p.recheio,
      prioridade: p.prioridade,
      horaLimite: p.horaLimite,
    }));

    return e.json(200, {
      necessarios: necessarios,
      produzir: produzir,
      porReceita: porReceita,
      custoTotal: custoTotal,
    });
  },
  $apis.requireAuth('users', '_superusers'),
);

// --- POST /api/gc_turnkey/producoes/{id}/lista-compras --------------------
routerAdd(
  'POST',
  '/api/gc_turnkey/producoes/{id}/lista-compras',
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
    const pp = {}; // {ingId: {produtoId|'': g}}
    for (const it of ctx.itens) {
      const alvoG = num(it, 'quantidade_kg') * 1000;
      const parcial = cascade.explodeCompras(app, it.getString('receita'), alvoG, pp);
      for (const k in parcial) agg[k] = (agg[k] || 0) + parcial[k];

      // recheios / coberturas / extra — da ficha técnica se existir
      const fId = it.getString('formato');
      const recheioId = it.getString('recheio');
      const fichaExp = it.getString('ficha');
      const fx = fichaExp ? cascade.infoFicha(app, fichaExp, alvoG) : null;
      if (fId || fx) {
        let f;
        try {
          f = fId ? app.findRecordById('formatos_cookie', fId) : null;
        } catch (_) {
          f = null;
        }
        const massaG = fx ? fx.massaG : f ? num(f, 'massa_g') : 0;
        const recheioG = fx ? 0 : f ? num(f, 'recheio_g') : 0;
        const N = massaG > 0 ? Math.round(alvoG / massaG) : 0;
        if (N > 0) {
          const fichaId =
            fichaExp ||
            cascade.resolverFicha(
              app,
              ctx.empresaId,
              it.getString('receita'),
              recheioId || '',
              fId,
            );
          if (fichaId) {
            const slots = app.findRecordsByFilter(
              'itens_ficha',
              "ficha = {:f} && slot != 'massa'",
              '',
              0,
              0,
              { f: fichaId },
            );
            for (const sl of slots) {
              const g = num(sl, 'quantidade_g') * N;
              if (g <= 0) continue;
              const pr = cascade.explodeComprasDe(
                app,
                g,
                sl.getString('receita'),
                sl.getString('ingrediente'),
                pp,
              );
              for (const k in pr) agg[k] = (agg[k] || 0) + pr[k];
            }
          } else if (recheioId && recheioG > 0) {
            const pr = cascade.explodeCompras(app, recheioId, N * recheioG, pp);
            for (const k in pr) agg[k] = (agg[k] || 0) + pr[k];
          }
        }
      }
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
        const faltaG = Math.max(0, necessario - emStock);

        // Divide o que falta pelos produtos fixados nas receitas (o stock é um só,
        // do ingrediente); o que não fixa produto fica em "automático" ('').
        const baldes = pp[ingId] || {};
        const partes = {}; // produtoId|'' -> { prod, g }
        let somaB = 0;
        for (const pid in baldes) {
          let prod = null;
          if (pid !== '') {
            try {
              prod = tx.findRecordById('ingrediente_produtos', pid);
              if (prod.getString('ingrediente') !== ingId) prod = null;
            } catch (_) {
              prod = null;
            }
          }
          const chave = prod ? prod.id : '';
          if (!partes[chave]) partes[chave] = { prod: prod, g: 0 };
          partes[chave].g += baldes[pid];
          somaB += baldes[pid];
        }
        if (somaB <= 0) partes[''] = { prod: null, g: necessario };
        const totalB = somaB > 0 ? somaB : necessario;

        const manter = {};
        for (const chave in partes) {
          const parte = partes[chave];
          const prod = parte.prod;
          const necessarioP = necessario * (parte.g / totalB);
          const faltaP = faltaG * (parte.g / totalB);
          const embProd = prod ? num(prod, 'embalagem_g') : 0;
          const embG = embProd > 0 ? embProd : num(ing, 'gramas_embalagem');
          const precoProd = prod ? num(prod, 'preco') : 0;
          const cpg =
            embProd > 0 && precoProd > 0
              ? precoProd / embProd
              : num(ing, 'gramas_embalagem') > 0
                ? num(ing, 'preco') / num(ing, 'gramas_embalagem')
                : 0;
          const comprar = Math.max(0, embG > 0 ? Math.ceil(faltaP / embG - 1e-9) * embG : faltaP);

          const existentes = tx.findRecordsByFilter(
            'lista_compras',
            'empresa = {:e} && ingrediente = {:i} && comprado = false && producao = {:p} && produto = {:pr}',
            '',
            1,
            0,
            { e: ctx.empresaId, i: ingId, p: ctx.producao.id, pr: chave },
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
          row.set('produto', chave);
          row.set(
            'descricao',
            prod
              ? ing.getString('nome') + ' — ' + (prod.getString('marca') || prod.getString('nome'))
              : ing.getString('nome'),
          );
          row.set('fornecedor', (prod && prod.getString('fornecedor')) || ing.getString('fornecedor'));
          row.set('quantidade_necessaria_g', necessarioP);
          row.set('quantidade_comprar_g', comprar);
          row.set('embalagem_g', embG);
          row.set('custo_estimado', comprar * cpg);
          tx.save(row);
          manter[row.id] = true;
          linhas++;
        }
        // linhas antigas deste ingrediente (ex.: de um produto que já não está fixado)
        const antigas = tx.findRecordsByFilter(
          'lista_compras',
          'empresa = {:e} && ingrediente = {:i} && comprado = false && producao = {:p}',
          '',
          0,
          0,
          { e: ctx.empresaId, i: ingId, p: ctx.producao.id },
        );
        for (const a of antigas) if (!manter[a.id]) tx.delete(a);
      }
    });

    return e.json(200, { linhas: linhas });
  },
  $apis.requireAuth('users', '_superusers'),
);

// --- POST /api/gc_turnkey/producoes/{id}/concluir ------------------------
routerAdd(
  'POST',
  '/api/gc_turnkey/producoes/{id}/concluir',
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

      // Consome as linhas diretas de uma receita escaladas para que a soma
      // das quantidades seja `alvoG` g (percentagem de cada ingrediente).
      const consumirLinhasDe = (receitaRec, alvoG) => {
        const linhas = tx.findRecordsByFilter(
          'itens_receita',
          'receita = {:id}',
          '',
          0,
          0,
          { id: receitaRec.id },
        );
        let pesoBase = 0;
        for (const l of linhas) pesoBase += num(l, 'quantidade_g');
        const fator = pesoBase > 0 ? alvoG / pesoBase : 0;
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
              faltas.push(
                'Sub-receita sem stock: ' + l.getString('nome_provisorio'),
              );
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
        const formatoId = it.getString('formato');
        const fichaExp = it.getString('ficha');
        const fx = fichaExp ? cascade.infoFicha(tx, fichaExp, alvoG) : null;

        // consumo da massa
        consumirLinhasDe(receita, alvoG);

        if (formatoId || fx) {
          let formato = null;
          if (formatoId) {
            try {
              formato = tx.findRecordById('formatos_cookie', formatoId);
            } catch (_) {
              formato = null;
            }
          }
          const massaG = fx ? fx.massaG : formato ? num(formato, 'massa_g') : 0;
          const recheioG = fx ? 0 : formato ? num(formato, 'recheio_g') : 0;
          const N = massaG > 0 ? Math.round(alvoG / massaG) : 0;
          const recheioId = it.getString('recheio');

          it.set('unidades_previstas', N);
          tx.save(it);

          const fichaId =
            (fx ? fichaExp : '') ||
            cascade.resolverFicha(
              tx,
              ctx.empresaId,
              receitaId,
              recheioId || '',
              formatoId,
            );
          const nomeProduto = fx
            ? fx.nome
            : receita.getString('nome') +
              (formato ? ' — ' + formato.getString('nome') : '');

          if (fichaId && N > 0) {
            // Recheios / coberturas / extra: quantidades por unidade da ficha.
            const slots = tx.findRecordsByFilter(
              'itens_ficha',
              "ficha = {:f} && slot != 'massa'",
              '',
              0,
              0,
              { f: fichaId },
            );
            for (const sl of slots) {
              const g = num(sl, 'quantidade_g') * N;
              if (g <= 0) continue;
              const recSlot = sl.getString('receita');
              const ingSlot = sl.getString('ingrediente');
              if (recSlot) {
                let rr;
                try {
                  rr = tx.findRecordById('receitas', recSlot);
                } catch (_) {
                  rr = null;
                }
                if (rr) consumirLinhasDe(rr, g);
              } else if (ingSlot) {
                let ing;
                try {
                  ing = tx.findRecordById('ingredientes', ingSlot);
                } catch (_) {
                  ing = null;
                }
                if (ing) consumir(ing, g, ing.getString('nome'));
              }
            }

            cascade.aplicarMovimento(
              tx,
              { empresaId: ctx.empresaId, fichaId: fichaId },
              N,
              'saida_producao',
              { autorId: ctx.autorId, producaoId: ctx.producao.id },
            );
            saidas.push({ nome: nomeProduto, gramas: N, unidades: N });
          } else {
            // Sem ficha: usa o recheio indicado à mão (se houver).
            if (recheioId && recheioG > 0 && N > 0) {
              let recheioRec;
              try {
                recheioRec = tx.findRecordById('receitas', recheioId);
              } catch (_) {
                recheioRec = null;
              }
              if (recheioRec) consumirLinhasDe(recheioRec, N * recheioG);
            }
            faltas.push(
              'Sem ficha técnica para ' +
                nomeProduto +
                (recheioId ? ' (com recheio)' : '') +
                ' — produto não entrou em stock.',
            );
          }
        } else {
          // sem formato: comportamento antigo (ingrediente-espelho)
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

// --- GET /api/gc_turnkey/fichas/resolver ---------------------------------
// Devolve a ficha técnica que corresponde a uma massa + formato (+ recheio),
// com os componentes (recheios/coberturas/extra) e a quantidade por unidade.
//   query: massa, formato, recheio?
routerAdd(
  'GET',
  '/api/gc_turnkey/fichas/resolver',
  (e) => {
    const cascade = require(`${__hooks}/cascade.js`);
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
    const massaId = q.massa || '';
    const formatoId = q.formato || '';
    const recheioId = q.recheio || '';
    if (!massaId) throw new BadRequestError('massa em falta.');

    const app = e.app;
    const fichaId = cascade.resolverFicha(
      app,
      empresaId,
      massaId,
      recheioId,
      formatoId,
    );
    if (!fichaId) return e.json(200, { fichaId: '' });

    const num = (rec, f) => {
      try {
        return rec.getFloat(f);
      } catch (_) {
        return 0;
      }
    };
    let ficha;
    try {
      ficha = app.findRecordById('fichas_tecnicas', fichaId);
    } catch (_) {
      return e.json(200, { fichaId: '' });
    }
    const slots = app.findRecordsByFilter(
      'itens_ficha',
      "ficha = {:f} && slot != 'massa'",
      '',
      0,
      0,
      { f: fichaId },
    );
    const componentes = [];
    for (const sl of slots) {
      let nome = '';
      const recSlot = sl.getString('receita');
      const ingSlot = sl.getString('ingrediente');
      try {
        if (recSlot) nome = app.findRecordById('receitas', recSlot).getString('nome');
        else if (ingSlot)
          nome = app.findRecordById('ingredientes', ingSlot).getString('nome');
      } catch (_) {}
      if (!nome) continue;
      componentes.push({
        slot: sl.getString('slot'),
        nome: nome,
        gPorUnidade: num(sl, 'quantidade_g'),
      });
    }
    return e.json(200, {
      fichaId: fichaId,
      nome: ficha.getString('nome'),
      componentes: componentes,
    });
  },
  $apis.requireAuth('users', '_superusers'),
);

// --- GET /api/gc_turnkey/receitas/{id}/plano -----------------------------
// Mise en place de UMA receita, sem precisar de uma produção agendada.
//   ?kg=  (obrigatório)  &formato=  &recheio=  &empresa=(só superuser)
routerAdd(
  'GET',
  '/api/gc_turnkey/receitas/{id}/plano',
  (e) => {
    const cascade = require(`${__hooks}/cascade.js`);
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
    const app = e.app;
    const num = (rec, f) => {
      try {
        return rec.getFloat(f);
      } catch (_) {
        return 0;
      }
    };
    const nomeReceita = (id) => {
      try {
        return app.findRecordById('receitas', id).getString('nome');
      } catch (_) {
        return '';
      }
    };
    const merge = (dst, src) => {
      for (const k in src) dst[k] = (dst[k] || 0) + src[k];
    };

    const receitaId = e.request.pathValue('id');
    let receita;
    try {
      receita = app.findRecordById('receitas', receitaId);
    } catch (_) {
      throw new NotFoundError('Receita não encontrada.');
    }
    const q = e.requestInfo().query;
    const kg = Number(q.kg || 0);
    if (!isFinite(kg) || kg <= 0) throw new BadRequestError('kg inválido.');
    const alvoG = kg * 1000;
    const formatoId = q.formato || '';
    const recheioId = q.recheio || '';

    let massaG = 0;
    let unidades = 0;
    let formatoNome = '';
    if (formatoId) {
      try {
        const f = app.findRecordById('formatos_cookie', formatoId);
        massaG = num(f, 'massa_g');
        formatoNome = f.getString('nome');
        unidades = massaG > 0 ? Math.round(alvoG / massaG) : 0;
      } catch (_) {}
    }

    const ep = cascade.explodeProducao(app, receitaId, alvoG);
    const comprarMap = {};
    const intermediosMap = {};
    merge(comprarMap, ep.comprar);
    merge(intermediosMap, ep.produzir);

    if (formatoId && unidades > 0) {
      const fichaId = cascade.resolverFicha(
        app,
        empresaId,
        receitaId,
        recheioId || '',
        formatoId,
      );
      if (fichaId) {
        const slots = app.findRecordsByFilter(
          'itens_ficha',
          "ficha = {:f} && slot != 'massa'",
          '',
          0,
          0,
          { f: fichaId },
        );
        for (const sl of slots) {
          const g = num(sl, 'quantidade_g') * unidades;
          if (g <= 0) continue;
          merge(
            comprarMap,
            cascade.explodeComprasDe(
              app,
              g,
              sl.getString('receita'),
              sl.getString('ingrediente'),
            ),
          );
          const recSlot = sl.getString('receita');
          if (recSlot) {
            intermediosMap[recSlot] = (intermediosMap[recSlot] || 0) + g;
          } else {
            const ingSlot = sl.getString('ingrediente');
            try {
              const ig = app.findRecordById('ingredientes', ingSlot);
              const esp = ig.getString('receita_espelho');
              if (ig.getString('origem') === 'fabrico_proprio' && esp) {
                intermediosMap[esp] = (intermediosMap[esp] || 0) + g;
              }
            } catch (_) {}
          }
        }
      } else if (recheioId) {
        const recheioG = massaG > 0
          ? (() => {
              try {
                return num(
                  app.findRecordById('formatos_cookie', formatoId),
                  'recheio_g',
                );
              } catch (_) {
                return 0;
              }
            })()
          : 0;
        if (recheioG > 0) {
          const gRecheio = unidades * recheioG;
          merge(comprarMap, cascade.explodeCompras(app, recheioId, gRecheio));
          intermediosMap[recheioId] =
            (intermediosMap[recheioId] || 0) + gRecheio;
        }
      }
    }

    const emStockDe = (ingId) => {
      const inv = app.findRecordsByFilter(
        'inventario',
        'empresa = {:e} && ingrediente = {:i}',
        '',
        1,
        0,
        { e: empresaId, i: ingId },
      );
      return inv.length > 0 ? inv[0].getFloat('quantidade') : 0;
    };

    const comprar = [];
    for (const k in comprarMap) {
      let ing;
      try {
        ing = app.findRecordById('ingredientes', k);
      } catch (_) {
        continue;
      }
      comprar.push({
        ingredienteId: k,
        nome: ing.getString('nome'),
        gramas: comprarMap[k],
        emStock: emStockDe(k),
      });
    }
    comprar.sort((a, b) => a.nome.localeCompare(b.nome));

    const intermedios = [];
    for (const k in intermediosMap) {
      intermedios.push({
        receitaId: k,
        nome: nomeReceita(k),
        gramas: intermediosMap[k],
      });
    }
    intermedios.sort((a, b) => a.nome.localeCompare(b.nome));

    return e.json(200, {
      receitaId: receitaId,
      nome: receita.getString('nome'),
      kg: kg,
      unidades: unidades,
      formato: formatoNome,
      recheio: recheioId ? nomeReceita(recheioId) : '',
      comprar: comprar,
      intermedios: intermedios,
    });
  },
  $apis.requireAuth('users', '_superusers'),
);

// --- GET /api/gc_turnkey/fichas/{id}/plano -------------------------------
// Mise en place de um PRODUTO FINAL (ficha técnica): para N unidades, o que
// produzir primeiro (massa, recheios, coberturas e sub-receitas) e os
// ingredientes a pesar/comprar.
//   ?unidades=  (obrigatório)  &empresa=(só superuser)
routerAdd(
  'GET',
  '/api/gc_turnkey/fichas/{id}/plano',
  (e) => {
    const cascade = require(`${__hooks}/cascade.js`);
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
    const app = e.app;

    const fichaId = e.request.pathValue('id');
    let ficha;
    try {
      ficha = app.findRecordById('fichas_tecnicas', fichaId);
    } catch (_) {
      throw new NotFoundError('Ficha não encontrada.');
    }
    if (ficha.getString('empresa') !== empresaId) {
      throw new NotFoundError('Ficha não encontrada.');
    }
    const unidades = Math.round(Number(e.requestInfo().query.unidades || 0));
    if (!isFinite(unidades) || unidades <= 0) {
      throw new BadRequestError('unidades inválidas.');
    }

    const plano = cascade.planoFicha(app, fichaId, unidades);
    if (!plano) {
      throw new BadRequestError(
        'Esta ficha não tem massa (receita) definida — não dá para produzir.',
      );
    }
    const info = plano.info;

    const nomeReceita = (id) => {
      try {
        return app.findRecordById('receitas', id).getString('nome');
      } catch (_) {
        return '';
      }
    };
    const emStockDe = (ingId) => {
      const inv = app.findRecordsByFilter(
        'inventario',
        'empresa = {:e} && ingrediente = {:i}',
        '',
        1,
        0,
        { e: empresaId, i: ingId },
      );
      return inv.length > 0 ? inv[0].getFloat('quantidade') : 0;
    };

    const comprar = [];
    for (const k in plano.comprar) {
      let ing;
      try {
        ing = app.findRecordById('ingredientes', k);
      } catch (_) {
        continue;
      }
      comprar.push({
        ingredienteId: k,
        nome: ing.getString('nome'),
        gramas: plano.comprar[k],
        emStock: emStockDe(k),
      });
    }
    comprar.sort((a, b) => a.nome.localeCompare(b.nome));

    // A massa vem primeiro; depois recheios/coberturas/etc. por nome.
    const intermedios = [];
    for (const k in plano.produzir) {
      intermedios.push({
        receitaId: k,
        nome: nomeReceita(k),
        gramas: plano.produzir[k],
        eMassa: k === info.massaReceitaId,
      });
    }
    intermedios.sort((a, b) =>
      a.eMassa === b.eMassa
        ? a.nome.localeCompare(b.nome)
        : a.eMassa
          ? -1
          : 1,
    );

    return e.json(200, {
      fichaId: fichaId,
      nome: info.nome,
      receitaId: info.massaReceitaId,
      massaReceitaNome: nomeReceita(info.massaReceitaId),
      massaGPorUnidade: info.massaG,
      kg: (info.massaG * unidades) / 1000,
      unidades: unidades,
      formatoId: info.formatoId,
      formato: info.formatoNome,
      recheio: '',
      comprar: comprar,
      intermedios: intermedios,
    });
  },
  $apis.requireAuth('users', '_superusers'),
);
