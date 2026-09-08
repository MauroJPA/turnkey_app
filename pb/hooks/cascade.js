/// <reference path="../pb_data/types.d.ts" />

// Motor de cascata de custos.
//
// Tudo dentro de UMA função exportada, com os auxiliares como closures — o
// require() do PocketBase não mantém de forma fiável a visibilidade entre
// funções de topo de um módulo.
//
//   runCascade(app, 'ingrediente'|'receita', id)

function runCascade(app, kind, rootId) {
  const EPS = 0.001;
  const seen = new Set();

  const fnum = (rec, field) => {
    try {
      return rec.getFloat(field);
    } catch (_) {
      return 0;
    }
  };

  const ingCpg = (ing) => {
    const g = fnum(ing, 'gramas_embalagem');
    return g > 0 ? fnum(ing, 'preco') / g : 0;
  };

  const parentRecipeIds = (field, id) => {
    const rows = app.findRecordsByFilter(
      'itens_receita',
      field + ' = {:id}',
      '',
      0,
      0,
      { id: id },
    );
    const out = new Set();
    for (const r of rows) {
      const rid = r.getString('receita');
      if (rid) out.add(rid);
    }
    return out;
  };

  const escreverHistorico = (tipo, entidadeId, empresaId, descricao, antes, depois) => {
    try {
      const h = new Record(app.findCollectionByNameOrId('historico'));
      h.set('empresa', empresaId);
      h.set('entidade_tipo', tipo);
      h.set('entidade_id', entidadeId);
      h.set('descricao', descricao);
      h.set('valor_antes', antes);
      h.set('valor_depois', depois);
      app.save(h);
    } catch (err) {
      console.log('[cascata] historico: ' + err);
    }
  };

  const recomputeFicha = (fichaId) => {
    let ficha;
    try {
      ficha = app.findRecordById('fichas_tecnicas', fichaId);
    } catch (_) {
      return;
    }
    const empresaId = ficha.getString('empresa');

    const itens = app.findRecordsByFilter(
      'itens_ficha',
      'ficha = {:id}',
      '',
      0,
      0,
      { id: fichaId },
    );

    let custo = 0;
    let peso = 0;
    for (const item of itens) {
      const qtd = fnum(item, 'quantidade_g');
      peso += qtd;
      const ingRel = item.getString('ingrediente');
      const recRel = item.getString('receita');
      if (ingRel) {
        let ing;
        try {
          ing = app.findRecordById('ingredientes', ingRel);
        } catch (_) {
          continue;
        }
        // sempre a partir do preço/gramas — o custo_por_grama do ingrediente
        // é só cache de UI e pode estar desatualizado.
        custo += ingCpg(ing) * qtd;
      } else if (recRel) {
        let rec;
        try {
          rec = app.findRecordById('receitas', recRel);
        } catch (_) {
          continue;
        }
        custo += fnum(rec, 'custo_por_grama') * qtd;
      }
    }

    const custoAntes = fnum(ficha, 'custo_produto');
    const pesoAntes = fnum(ficha, 'peso_produto');
    if (
      Math.abs(custoAntes - custo) > EPS ||
      Math.abs(pesoAntes - peso) > EPS
    ) {
      ficha.set('custo_produto', custo);
      ficha.set('peso_produto', peso);
      app.save(ficha);
      escreverHistorico(
        'ficha',
        fichaId,
        empresaId,
        'Recalculo: EUR ' +
          custoAntes.toFixed(2) +
          ' -> ' +
          custo.toFixed(2) +
          ' | Peso: ' +
          pesoAntes.toFixed(0) +
          'g -> ' +
          peso.toFixed(0) +
          'g',
        { custo: custoAntes, peso: pesoAntes },
        { custo: custo, peso: peso },
      );
    }
  };

  const fichasQueUsam = (field, id) => {
    let rows;
    try {
      rows = app.findRecordsByFilter(
        'itens_ficha',
        field + ' = {:id}',
        '',
        0,
        0,
        { id: id },
      );
    } catch (_) {
      return new Set();
    }
    const out = new Set();
    for (const r of rows) {
      const fid = r.getString('ficha');
      if (fid) out.add(fid);
    }
    return out;
  };

  const sincronizarEspelho = (receita, custo, rendimento, cpg) => {
    const publicar = receita.getBool('publicar_como_ingrediente');
    const empresaId = receita.getString('empresa');

    let espelho = null;
    const achados = app.findRecordsByFilter(
      'ingredientes',
      'receita_espelho = {:id}',
      '',
      1,
      0,
      { id: receita.id },
    );
    if (achados.length > 0) espelho = achados[0];

    if (!publicar) {
      if (espelho && !espelho.getBool('deletado')) {
        espelho.set('deletado', true);
        app.save(espelho);
      }
      return;
    }

    if (!espelho) {
      espelho = new Record(app.findCollectionByNameOrId('ingredientes'));
      espelho.set('empresa', empresaId);
      espelho.set('receita_espelho', receita.id);
      espelho.set('origem', 'fabrico_proprio');
      espelho.set('marca', '(receita)');
    }
    espelho.set('nome', receita.getString('nome'));
    espelho.set('preco', custo);
    espelho.set('gramas_embalagem', rendimento);
    espelho.set('custo_por_grama', cpg);
    espelho.set('disponivel', true);
    espelho.set('deletado', false);
    app.save(espelho);

    recomputeIngrediente(espelho.id);
  };

  const recomputeReceita = (id) => {
    if (seen.has(id)) return;
    seen.add(id);

    let receita;
    try {
      receita = app.findRecordById('receitas', id);
    } catch (_) {
      return;
    }
    const empresaId = receita.getString('empresa');

    const itens = app.findRecordsByFilter(
      'itens_receita',
      'receita = {:id}',
      '',
      0,
      0,
      { id: id },
    );

    let custo = 0;
    let peso = 0;
    for (const item of itens) {
      const qtd = fnum(item, 'quantidade_g');
      peso += qtd;
      const ingRel = item.getString('ingrediente');
      const subRel = item.getString('sub_receita');
      if (ingRel) {
        let ing;
        try {
          ing = app.findRecordById('ingredientes', ingRel);
        } catch (_) {
          continue;
        }
        // sempre a partir do preço/gramas — o custo_por_grama do ingrediente
        // é só cache de UI e pode estar desatualizado.
        custo += ingCpg(ing) * qtd;
      } else if (subRel) {
        recomputeReceita(subRel);
        let sub;
        try {
          sub = app.findRecordById('receitas', subRel);
        } catch (_) {
          continue;
        }
        custo += fnum(sub, 'custo_por_grama') * qtd;
      }
    }

    const manual = receita.getBool('rendimento_manual');
    const rendimento = manual ? fnum(receita, 'rendimento_esperado') : peso;
    const cpgReceita = rendimento > 0 ? custo / rendimento : 0;

    const custoAntes = fnum(receita, 'custo_receita');
    const pesoAntes = fnum(receita, 'rendimento_esperado');
    const mudou =
      Math.abs(custoAntes - custo) > EPS ||
      Math.abs(fnum(receita, 'custo_por_grama') - cpgReceita) >
        cpgReceita * 1e-6 + 1e-9 ||
      (!manual && Math.abs(pesoAntes - peso) > EPS);

    if (mudou) {
      receita.set('custo_receita', custo);
      receita.set('custo_por_grama', cpgReceita);
      if (!manual) receita.set('rendimento_esperado', peso);
      app.save(receita);
      escreverHistorico(
        'receita',
        id,
        empresaId,
        'Recalculo: EUR ' +
          custoAntes.toFixed(2) +
          ' -> ' +
          custo.toFixed(2) +
          ' | Peso: ' +
          pesoAntes.toFixed(0) +
          'g -> ' +
          (manual ? pesoAntes : peso).toFixed(0) +
          'g',
        { custo: custoAntes, peso: pesoAntes },
        { custo: custo, peso: manual ? pesoAntes : peso },
      );
    }

    sincronizarEspelho(receita, custo, rendimento, cpgReceita);

    for (const rid of parentRecipeIds('sub_receita', id)) recomputeReceita(rid);

    for (const fid of fichasQueUsam('receita', id)) recomputeFicha(fid);
  };

  const recomputeIngrediente = (ingId) => {
    let ing;
    try {
      ing = app.findRecordById('ingredientes', ingId);
    } catch (_) {
      return;
    }
    const cpg = ingCpg(ing);
    // epsilon relativo — custo_por_grama pode ser muito pequeno (0,0005…)
    if (Math.abs(fnum(ing, 'custo_por_grama') - cpg) > cpg * 1e-6 + 1e-9) {
      ing.set('custo_por_grama', cpg);
      app.save(ing);
    }
    for (const rid of parentRecipeIds('ingrediente', ingId)) {
      recomputeReceita(rid);
    }
    for (const fid of fichasQueUsam('ingrediente', ingId)) {
      recomputeFicha(fid);
    }
  };

  if (kind === 'ingrediente') recomputeIngrediente(rootId);
  else if (kind === 'ficha') recomputeFicha(rootId);
  else recomputeReceita(rootId);
}

// ---------------------------------------------------------------------------
// Explosão para compras: dado uma receita e a quantidade-alvo em gramas,
// devolve { [ingredienteId]: gramas } SÓ dos ingredientes `comprado`, descendo
// por sub-receitas e por ingredientes de fabrico próprio com receita_espelho.
// ---------------------------------------------------------------------------
function explodeCompras(app, receitaId, alvoG) {
  const num = (rec, f) => {
    try {
      return rec.getFloat(f);
    } catch (_) {
      return 0;
    }
  };
  const acc = {};
  const seen = new Set();

  const walk = (recId, alvo) => {
    if (seen.has(recId)) return;
    seen.add(recId);

    let receita;
    try {
      receita = app.findRecordById('receitas', recId);
    } catch (_) {
      seen.delete(recId);
      return;
    }
    const rend = num(receita, 'rendimento_esperado');
    const fator = rend > 0 ? alvo / rend : 0;

    const itens = app.findRecordsByFilter(
      'itens_receita',
      'receita = {:id}',
      '',
      0,
      0,
      { id: recId },
    );
    for (const it of itens) {
      const g = num(it, 'quantidade_g') * fator;
      if (g <= 0) continue;
      const subRel = it.getString('sub_receita');
      const ingRel = it.getString('ingrediente');
      if (subRel) {
        walk(subRel, g);
      } else if (ingRel) {
        let ing;
        try {
          ing = app.findRecordById('ingredientes', ingRel);
        } catch (_) {
          continue;
        }
        const espelho = ing.getString('receita_espelho');
        if (ing.getString('origem') === 'fabrico_proprio' && espelho) {
          walk(espelho, g);
        } else {
          acc[ingRel] = (acc[ingRel] || 0) + g;
        }
      }
    }
    seen.delete(recId);
  };

  walk(receitaId, alvoG);
  return acc;
}

// ---------------------------------------------------------------------------
// Aplica um movimento de stock: upsert da linha `inventario` do item e cria
// um registo em `movimentos_inventario`. Devolve a quantidade final.
// item = { empresaId, ingredienteId?, fichaId? }
// ---------------------------------------------------------------------------
function aplicarMovimento(app, item, delta, motivo, opts) {
  opts = opts || {};
  const alvoCampo = item.ingredienteId ? 'ingrediente' : 'ficha';
  const alvoId = item.ingredienteId || item.fichaId;
  if (!alvoId) throw new BadRequestError('Falta ingrediente ou ficha.');

  const achados = app.findRecordsByFilter(
    'inventario',
    'empresa = {:e} && ' + alvoCampo + ' = {:i}',
    '',
    1,
    0,
    { e: item.empresaId, i: alvoId },
  );

  let linha;
  if (achados.length > 0) {
    linha = achados[0];
  } else {
    linha = new Record(app.findCollectionByNameOrId('inventario'));
    linha.set('empresa', item.empresaId);
    linha.set(alvoCampo, alvoId);
    linha.set('quantidade', 0);
  }

  let q = linha.getFloat('quantidade') + delta;
  if (q < 0) q = 0;
  linha.set('quantidade', q);
  app.save(linha);

  const mov = new Record(app.findCollectionByNameOrId('movimentos_inventario'));
  mov.set('empresa', item.empresaId);
  mov.set(alvoCampo, alvoId);
  mov.set('delta', delta);
  mov.set('motivo', motivo);
  if (opts.producaoId) mov.set('producao', opts.producaoId);
  if (opts.autorId) mov.set('autor', opts.autorId);
  if (opts.notas) mov.set('notas', opts.notas);
  app.save(mov);

  return q;
}

// Resolve a ficha técnica (produto acabado) correspondente a uma combinação
// massa + recheio + formato. Devolve o id da ficha ou '' se não houver uma
// que corresponda inequivocamente.
function resolverFicha(app, empresaId, massaId, recheioId, formatoId) {
  if (!massaId) return '';
  const linhasMassa = app.findRecordsByFilter(
    'itens_ficha',
    "empresa = {:e} && slot = 'massa' && receita = {:r}",
    '',
    0,
    0,
    { e: empresaId, r: massaId },
  );
  for (const lm of linhasMassa) {
    const fichaId = lm.getString('ficha');
    if (!fichaId) continue;

    let ficha;
    try {
      ficha = app.findRecordById('fichas_tecnicas', fichaId);
    } catch (_) {
      continue;
    }
    if (ficha.getString('deletado') === 'true' || ficha.get('deletado') === true) {
      continue;
    }
    if (formatoId && ficha.getString('formato') !== formatoId) continue;

    const recheios = app.findRecordsByFilter(
      'itens_ficha',
      "ficha = {:f} && (slot = 'recheio_base' || slot = 'recheio_top')",
      '',
      0,
      0,
      { f: fichaId },
    );
    if (recheioId) {
      let ok = false;
      for (const r of recheios) {
        if (r.getString('receita') === recheioId) {
          ok = true;
          break;
        }
      }
      if (!ok) continue;
    } else if (recheios.length > 0) {
      // pediram sem recheio mas a ficha tem recheio -> não corresponde
      continue;
    }
    return fichaId;
  }
  return '';
}

// Valida o acesso a uma produção pelo `{id}` da rota e devolve o contexto.
function carregarProducao(e, exigeEscrita) {
  const auth = e.auth;
  const isSuper =
    auth && auth.collection() && auth.collection().name === '_superusers';
  const id = e.request.pathValue('id');
  const producao = e.app.findRecordById('producoes', id);
  const empresaId = producao.getString('empresa');

  if (!isSuper) {
    if (!auth || auth.collection().name !== 'users') {
      throw new ForbiddenError('Autenticação necessária.');
    }
    if (auth.getString('empresa') !== empresaId) {
      throw new ForbiddenError('Produção de outra empresa.');
    }
    if (exigeEscrita && auth.getString('papel') === 'viewer') {
      throw new ForbiddenError('Sem permissão.');
    }
  }

  const itens = e.app.findRecordsByFilter(
    'producao_itens',
    'producao = {:id}',
    '',
    0,
    0,
    { id: id },
  );
  return {
    producao: producao,
    empresaId: empresaId,
    itens: itens,
    autorId: auth && !isSuper ? auth.id : null,
  };
}

module.exports = {
  runCascade,
  explodeCompras,
  aplicarMovimento,
  carregarProducao,
  resolverFicha,
};
