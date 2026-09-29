/// <reference path="../pb_data/types.d.ts" />

// Motor de cascata de custos.
//
// Tudo dentro de UMA função exportada, com os auxiliares como closures — o
// require() do PocketBase não mantém de forma fiável a visibilidade entre
// funções de topo de um módulo.
//
//   runCascade(app, 'ingrediente'|'receita', id)

// Fator para converter a quantidade NATIVA de um ingrediente em gramas (peso):
// g -> 1; ml -> densidade (`nutri_densidade`, 1 por omissão); un -> peso de cada
// unidade (`gramas_unidade`, 1 por omissão). Custos, stock e compras ficam na
// unidade nativa; o peso da receita e a nutrição usam gramas.
function fatorPesoIng(ing) {
  const u = ing.getString('unidade');
  if (u === 'ml') {
    const d = ing.getFloat('nutri_densidade');
    return d > 0 ? d : 1;
  }
  if (u === 'un') {
    const g = ing.getFloat('gramas_unidade');
    return g > 0 ? g : 1;
  }
  return 1;
}

// Fator de uma linha (de receita/ficha): 1 se não é um ingrediente.
function fatorPesoLinha(app, item) {
  const r = item.getString('ingrediente');
  if (!r) return 1;
  try {
    return fatorPesoIng(app.findRecordById('ingredientes', r));
  } catch (_) {
    return 1;
  }
}

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

  // custo por grama de uma linha de receita: se a linha fixa um produto de
  // compra DESSE ingrediente, é o do produto; senão, o do genérico.
  const cpgLinha = (item, ing) => {
    const pid = item.getString('produto');
    if (pid) {
      try {
        const p = app.findRecordById('ingrediente_produtos', pid);
        const g = fnum(p, 'embalagem_g');
        if (p.getString('ingrediente') === ing.id && g > 0 && fnum(p, 'preco') > 0) {
          return fnum(p, 'preco') / g;
        }
      } catch (_) {}
    }
    return ingCpg(ing);
  };

  // --- nutrição (mesma cascata dos custos) --------------------------------
  const NUT = [
    'kcal', 'lipidos', 'saturados', 'hidratos',
    'acucares', 'fibra', 'proteina', 'sal',
  ];
  const NUT_CAMPO = {
    kcal: 'nutri_energia_kcal',
    lipidos: 'nutri_lipidos_g',
    saturados: 'nutri_saturados_g',
    hidratos: 'nutri_hidratos_g',
    acucares: 'nutri_acucares_g',
    fibra: 'nutri_fibra_g',
    proteina: 'nutri_proteina_g',
    sal: 'nutri_sal_g',
  };
  const zeroN = () => ({
    kcal: 0, lipidos: 0, saturados: 0, hidratos: 0,
    acucares: 0, fibra: 0, proteina: 0, sal: 0,
  });
  const addEscN = (acc, src, f) => {
    for (const k of NUT) acc[k] += (src[k] || 0) * f;
  };
  const vazioN = (n) => NUT.every((k) => !n[k]);
  const por100De = (abs, pesoG) => {
    const o = zeroN();
    if (pesoG > 0) for (const k of NUT) o[k] = (abs[k] * 100) / pesoG;
    return o;
  };
  // nutrição por 100 g de um ingrediente (converte base 100ml -> 100g)
  const nutriIngPor100 = (ing) => {
    const n = zeroN();
    for (const k of NUT) n[k] = fnum(ing, NUT_CAMPO[k]);
    if (ing.getString('nutri_base') === '100ml') {
      const d = fnum(ing, 'nutri_densidade');
      if (d > 0) for (const k of NUT) n[k] = n[k] / d;
    }
    return n;
  };
  // nutrição por 100 g da linha de receita: se fixa um produto com nutrição
  // PRÓPRIA (desse ingrediente), são os valores do produto; senão, os do genérico.
  const nutriLinha = (item, ing) => {
    const pid = item.getString('produto');
    if (pid) {
      try {
        const p = app.findRecordById('ingrediente_produtos', pid);
        if (p.getString('ingrediente') === ing.id && p.getBool('nutri_propria')) {
          return {
            n100: nutriIngPor100(p),
            nome: p.getString('nome') || ing.getString('nome') || ing.id,
          };
        }
      } catch (_) {}
    }
    return { n100: nutriIngPor100(ing), nome: ing.getString('nome') || ing.id };
  };
  const listaSel = (rec, campo) => {
    try {
      const v = rec.get(campo);
      if (Array.isArray(v)) return v.map(String).filter(Boolean);
      if (typeof v === 'string' && v) return [v];
    } catch (_) {}
    return [];
  };
  // alergénios/vestígios EXTRA do produto que a linha fixa (só contam quando a
  // linha fixa esse produto; juntam-se aos do ingrediente genérico)
  const alergProduto = (item, ing, campo) => {
    const pid = item.getString('produto');
    if (!pid) return [];
    try {
      const p = app.findRecordById('ingrediente_produtos', pid);
      if (p.getString('ingrediente') !== ing.id) return [];
      return listaSel(p, campo);
    } catch (_) {
      return [];
    }
  };
  const unir = (a, b) => {
    const s = new Set(a);
    for (const x of b) s.add(x);
    return Array.from(s);
  };
  const perdaDe = (rec) =>
    Math.min(95, Math.max(0, fnum(rec, 'perda_cozedura_pct')));
  // Lê um campo `json` de um record (pode vir como objeto, string ou JSONRaw).
  const lerJson = (rec, campo) => {
    let v;
    try {
      v = rec.get(campo);
    } catch (_) {
      return null;
    }
    if (v == null || v === '') return null;
    if (
      typeof v === 'object' &&
      !Array.isArray(v) &&
      Object.keys(v).length > 0
    ) {
      return v;
    }
    try {
      return JSON.parse(String(v));
    } catch (_) {}
    return typeof v === 'object' ? v : null;
  };
  // nutri (por 100 g cru) em cache de uma receita já recalculada
  const receitaNutriPor100 = (recId) => {
    let rec;
    try {
      rec = app.findRecordById('receitas', recId);
    } catch (_) {
      return null;
    }
    const j = lerJson(rec, 'nutri');
    if (!j || typeof j !== 'object') return null;
    const p = j.por100g || {};
    const pc = j.por100g_cozido || {};
    const n = zeroN();
    const nc = zeroN();
    for (const k of NUT) {
      n[k] = Number(p[k] || 0);
      nc[k] = Number(pc[k] || 0);
    }
    return {
      por100: n,
      por100Cozido: nc,
      perda: perdaDe(rec),
      alergenios: Array.isArray(j.alergenios) ? j.alergenios : [],
      tracos: Array.isArray(j.alergenios_tracos) ? j.alergenios_tracos : [],
      completo: j.completo !== false,
      semDados: Array.isArray(j.sem_dados) ? j.sem_dados : [],
    };
  };
  // Se `ing` é um espelho de fabrico próprio, devolve o nutri da sua receita
  // (para tratar como sub-receita, incl. `sem_dados` em cascata); senão null.
  const espelhoNutri = (ing) => {
    if (!ing || ing.getString('origem') !== 'fabrico_proprio') return null;
    const recId = ing.getString('receita_espelho');
    if (!recId) return null;
    const s = receitaNutriPor100(recId);
    if (s) return s;
    return {
      por100: zeroN(),
      por100Cozido: zeroN(),
      perda: 0,
      alergenios: [],
      tracos: [],
      completo: false,
      semDados: [{ id: recId, nome: ing.getString('nome') || recId }],
    };
  };
  // dedup de {id, nome} (tolera entradas string de caches antigos)
  const dedupSemDados = (arr) => {
    const vistos = new Set();
    const out = [];
    for (const x of arr) {
      const e = typeof x === 'string' ? { id: '', nome: x } : x;
      const k = e.id || e.nome;
      if (k && !vistos.has(k)) {
        vistos.add(k);
        out.push(e);
      }
    }
    return out;
  };
  const nutriIgual = (aRaw, b) => {
    const a =
      aRaw && typeof aRaw === 'object' && Object.keys(aRaw).length
        ? aRaw
        : (() => {
            try {
              return JSON.parse(String(aRaw));
            } catch (_) {
              return null;
            }
          })();
    if (!a || !b || typeof a !== 'object' || typeof b !== 'object') return false;
    const pa = a.por100g || {};
    const pb = b.por100g || {};
    for (const k of NUT) {
      if (Math.abs(Number(pa[k] || 0) - Number(pb[k] || 0)) > 1e-4) return false;
    }
    const j = (x) => (x || []).slice().sort().join('|');
    return (
      j(a.alergenios) === j(b.alergenios) &&
      j(a.alergenios_tracos) === j(b.alergenios_tracos) &&
      (a.completo !== false) === (b.completo !== false)
    );
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
      const ingRel = item.getString('ingrediente');
      const recRel = item.getString('receita');
      const embRel = item.getString('embalagem');
      if (ingRel) {
        peso += qtd * fatorPesoLinha(app, item);
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
        peso += qtd;
        let rec;
        try {
          rec = app.findRecordById('receitas', recRel);
        } catch (_) {
          continue;
        }
        custo += fnum(rec, 'custo_por_grama') * qtd;
      } else if (embRel) {
        // embalagem: qtd = nº de peças; NÃO conta para o peso do produto.
        let emb;
        try {
          emb = app.findRecordById('embalagens', embRel);
        } catch (_) {
          continue;
        }
        const pecas = fnum(emb, 'unidades_compra') || 1;
        const rende = fnum(emb, 'rende_unidades') || 1;
        custo += (fnum(emb, 'preco_compra') / pecas / rende) * qtd;
      } else if (item.getString('kit')) {
        // kit de embalagens: qtd = nº de kits por unidade de produto; sem peso.
        let linhas;
        try {
          linhas = app.findRecordsByFilter(
            'embalagem_kit_itens',
            'kit = {:id}',
            '',
            0,
            0,
            { id: item.getString('kit') },
          );
        } catch (_) {
          linhas = [];
        }
        let cKit = 0;
        for (const kl of linhas) {
          let emb;
          try {
            emb = app.findRecordById('embalagens', kl.getString('embalagem'));
          } catch (_) {
            continue;
          }
          const pc = fnum(emb, 'unidades_compra') || 1;
          const rd = fnum(emb, 'rende_unidades') || 1;
          cKit += (fnum(emb, 'preco_compra') / pc / rd) * fnum(kl, 'quantidade');
        }
        custo += cKit * qtd;
      } else {
        peso += qtd;
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

    // --- nutrição da ficha (por 100 g de PRODUTO ACABADO) -------------
    const absF = zeroN();
    let pesoCru = 0;
    let perdaPond = 0;
    let alergF = [];
    let tracosF = [];
    let completoF = true;
    const semDadosF = [];
    for (const item of itens) {
      const qtd = fnum(item, 'quantidade_g') * fatorPesoLinha(app, item);
      if (qtd <= 0) continue;
      const ingRel = item.getString('ingrediente');
      const recRel = item.getString('receita');
      // embalagens não têm peso, nutrição nem alergénios.
      if (!ingRel && !recRel) continue;
      pesoCru += qtd;
      if (ingRel) {
        let ing;
        try {
          ing = app.findRecordById('ingredientes', ingRel);
        } catch (_) {
          continue;
        }
        // espelho de fabrico próprio -> desce pela receita (como sub-receita)
        const esp = espelhoNutri(ing);
        if (esp) {
          const pe =
            esp.por100Cozido && !vazioN(esp.por100Cozido)
              ? esp.por100Cozido
              : esp.por100;
          addEscN(absF, pe, qtd / 100);
          alergF = unir(alergF, esp.alergenios);
          tracosF = unir(tracosF, esp.tracos);
          if (!esp.completo) {
            completoF = false;
            for (const sd of esp.semDados) semDadosF.push(sd);
          }
          continue;
        }
        const n100 = nutriIngPor100(ing);
        if (vazioN(n100)) {
          completoF = false;
          semDadosF.push({ id: ingRel, nome: ing.getString('nome') || ingRel });
        }
        addEscN(absF, n100, qtd / 100);
        alergF = unir(alergF, listaSel(ing, 'alergenios'));
        tracosF = unir(tracosF, listaSel(ing, 'alergenios_tracos'));
      } else if (recRel) {
        const sub = receitaNutriPor100(recRel);
        if (sub) {
          addEscN(absF, sub.por100, qtd / 100);
          alergF = unir(alergF, sub.alergenios);
          tracosF = unir(tracosF, sub.tracos);
          if (!sub.completo) {
            completoF = false;
            for (const sd of sub.semDados) semDadosF.push(sd);
          }
          perdaPond += qtd * sub.perda;
        } else {
          completoF = false;
        }
      }
    }
    const perdaMedia = pesoCru > 0 ? perdaPond / pesoCru : 0;
    const pesoFinal = pesoCru * (1 - perdaMedia / 100);
    tracosF = tracosF.filter((t) => alergF.indexOf(t) < 0);
    // A água que sai a cozer não tem calorias: os totais da unidade mantêm-se;
    // muda o peso -> o "por 100 g" sobe.
    const novoNutriF = {
      por100g: por100De(absF, pesoFinal),
      por_unidade: absF,
      peso_cru_g: pesoCru,
      peso_unidade_g: pesoFinal,
      perda_media_pct: perdaMedia,
      alergenios: alergF.slice().sort(),
      alergenios_tracos: tracosF.slice().sort(),
      completo: completoF && pesoCru > 0,
      sem_dados: dedupSemDados(semDadosF),
      atualizado_em: new Date().toISOString(),
    };
    if (!nutriIgual(lerJson(ficha, 'nutri'), novoNutriF)) {
      ficha.set('nutri', novoNutriF);
      app.save(ficha);
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

  const sincronizarEspelho = (receita, custo, rendimento, cpg, nutri) => {
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
    // Nutrição do espelho = por 100 g do intermédio JÁ FEITO (cozido): quem o
    // usa mede-o em gramas do produto acabado (ex.: "20 g de brigadeiro").
    if (nutri && nutri.por100g_cozido) {
      for (const k of NUT) {
        espelho.set(NUT_CAMPO[k], Number(nutri.por100g_cozido[k] || 0));
      }
      espelho.set('nutri_base', '100g');
      espelho.set('nutri_densidade', 1);
      espelho.set('nutri_origem', 'receita');
      espelho.set('nutri_atualizado_em', new Date().toISOString());
      espelho.set('alergenios', nutri.alergenios || []);
      espelho.set('alergenios_tracos', nutri.alergenios_tracos || []);
    }
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
      peso += qtd * fatorPesoLinha(app, item);
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
        custo += cpgLinha(item, ing) * qtd;
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

    // --- nutrição da receita (por 100 g de mistura crua) ---------------
    const absN = zeroN();
    let pesoN = 0;
    let alergN = [];
    let tracosN = [];
    let completoN = true;
    const semDadosN = [];
    for (const item of itens) {
      const qtd = fnum(item, 'quantidade_g') * fatorPesoLinha(app, item);
      if (qtd <= 0) continue;
      pesoN += qtd;
      const ingRel = item.getString('ingrediente');
      const subRel = item.getString('sub_receita');
      if (ingRel) {
        let ing;
        try {
          ing = app.findRecordById('ingredientes', ingRel);
        } catch (_) {
          continue;
        }
        const esp = espelhoNutri(ing);
        if (esp) {
          const pe =
            esp.por100Cozido && !vazioN(esp.por100Cozido)
              ? esp.por100Cozido
              : esp.por100;
          addEscN(absN, pe, qtd / 100);
          alergN = unir(alergN, esp.alergenios);
          tracosN = unir(tracosN, esp.tracos);
          if (!esp.completo) {
            completoN = false;
            for (const sd of esp.semDados) semDadosN.push(sd);
          }
          continue;
        }
        const nl = nutriLinha(item, ing);
        const n100 = nl.n100;
        if (vazioN(n100)) {
          completoN = false;
          semDadosN.push({ id: ingRel, nome: nl.nome });
        }
        addEscN(absN, n100, qtd / 100);
        alergN = unir(alergN, listaSel(ing, 'alergenios'));
        tracosN = unir(tracosN, listaSel(ing, 'alergenios_tracos'));
        alergN = unir(alergN, alergProduto(item, ing, 'alergenios'));
        tracosN = unir(tracosN, alergProduto(item, ing, 'alergenios_tracos'));
      } else if (subRel) {
        const sub = receitaNutriPor100(subRel);
        if (sub) {
          addEscN(absN, sub.por100, qtd / 100);
          alergN = unir(alergN, sub.alergenios);
          tracosN = unir(tracosN, sub.tracos);
          if (!sub.completo) {
            completoN = false;
            for (const sd of sub.semDados) semDadosN.push(sd);
          }
        } else {
          completoN = false;
        }
      }
    }
    const por100 = por100De(absN, pesoN);
    const perdaPct = perdaDe(receita);
    const fCoz = perdaPct < 95 ? 1 / (1 - perdaPct / 100) : 1;
    const por100Coz = zeroN();
    for (const k of NUT) por100Coz[k] = por100[k] * fCoz;
    tracosN = tracosN.filter((t) => alergN.indexOf(t) < 0);
    const novoNutri = {
      por100g: por100,
      por100g_cozido: por100Coz,
      perda_pct: perdaPct,
      peso_base_g: pesoN,
      alergenios: alergN.slice().sort(),
      alergenios_tracos: tracosN.slice().sort(),
      completo: completoN && pesoN > 0,
      sem_dados: dedupSemDados(semDadosN),
      atualizado_em: new Date().toISOString(),
    };
    if (!nutriIgual(lerJson(receita, 'nutri'), novoNutri)) {
      receita.set('nutri', novoNutri);
      app.save(receita);
    }

    sincronizarEspelho(receita, custo, rendimento, cpgReceita, novoNutri);

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

  // custo por unidade de produto de um kit = soma de (custo/un de cada
  // embalagem × quantidade); atualiza o cache e re-corre as fichas que o usam.
  const recomputeKit = (kitId) => {
    let kit;
    try {
      kit = app.findRecordById('embalagem_kits', kitId);
    } catch (_) {
      return;
    }
    let linhas;
    try {
      linhas = app.findRecordsByFilter(
        'embalagem_kit_itens',
        'kit = {:id}',
        '',
        0,
        0,
        { id: kitId },
      );
    } catch (_) {
      linhas = [];
    }
    let cu = 0;
    for (const kl of linhas) {
      let emb;
      try {
        emb = app.findRecordById('embalagens', kl.getString('embalagem'));
      } catch (_) {
        continue;
      }
      const pc = fnum(emb, 'unidades_compra') || 1;
      const rd = fnum(emb, 'rende_unidades') || 1;
      cu += (fnum(emb, 'preco_compra') / pc / rd) * fnum(kl, 'quantidade');
    }
    if (Math.abs(fnum(kit, 'custo_unitario') - cu) > cu * 1e-6 + 1e-9) {
      kit.set('custo_unitario', cu);
      app.save(kit);
    }
    for (const fid of fichasQueUsam('kit', kitId)) {
      recomputeFicha(fid);
    }
  };

  const recomputeEmbalagem = (embId) => {
    let emb;
    try {
      emb = app.findRecordById('embalagens', embId);
    } catch (_) {
      return;
    }
    const pecas = fnum(emb, 'unidades_compra') || 1;
    const rende = fnum(emb, 'rende_unidades') || 1;
    const cu = fnum(emb, 'preco_compra') / pecas / rende;
    if (Math.abs(fnum(emb, 'custo_unitario') - cu) > cu * 1e-6 + 1e-9) {
      emb.set('custo_unitario', cu);
      app.save(emb);
    }
    for (const fid of fichasQueUsam('embalagem', embId)) {
      recomputeFicha(fid);
    }
    // kits que incluem esta embalagem -> recalcular (e as suas fichas).
    let kls;
    try {
      kls = app.findRecordsByFilter(
        'embalagem_kit_itens',
        'embalagem = {:id}',
        '',
        0,
        0,
        { id: embId },
      );
    } catch (_) {
      kls = [];
    }
    const vistos = {};
    for (const kl of kls) {
      const kid = kl.getString('kit');
      if (kid && !vistos[kid]) {
        vistos[kid] = true;
        recomputeKit(kid);
      }
    }
  };

  if (kind === 'ingrediente') recomputeIngrediente(rootId);
  else if (kind === 'ficha') recomputeFicha(rootId);
  else if (kind === 'embalagem') recomputeEmbalagem(rootId);
  else if (kind === 'kit') recomputeKit(rootId);
  else recomputeReceita(rootId);
}

// ---------------------------------------------------------------------------
// Explosão para compras: dado uma receita e a quantidade-alvo em gramas,
// devolve { [ingredienteId]: gramas } SÓ dos ingredientes `comprado`, descendo
// por sub-receitas e por ingredientes de fabrico próprio com receita_espelho.
// ---------------------------------------------------------------------------
// `porProduto` (opcional): se dado, regista também {[ingId]: {[produtoId|'']: g}} —
// o que cada receita pede de cada produto de compra fixado ('' = automático).
function explodeCompras(app, receitaId, alvoG, porProduto) {
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

    try {
      app.findRecordById('receitas', recId);
    } catch (_) {
      seen.delete(recId);
      return;
    }

    const itens = app.findRecordsByFilter(
      'itens_receita',
      'receita = {:id}',
      '',
      0,
      0,
      { id: recId },
    );
    // Escalar pela percentagem de cada linha: soma das linhas = alvo.
    let pesoBase = 0;
    for (const it of itens) pesoBase += num(it, 'quantidade_g') * fatorPesoLinha(app, it);
    const fator = pesoBase > 0 ? alvo / pesoBase : 0;

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
          if (porProduto) {
            const pid = it.getString('produto') || '';
            const b = (porProduto[ingRel] = porProduto[ingRel] || {});
            b[pid] = (b[pid] || 0) + g;
          }
        }
      }
    }
    seen.delete(recId);
  };

  walk(receitaId, alvoG);
  return acc;
}

// ---------------------------------------------------------------------------
// Como explodeCompras mas separa o que há para COMPRAR (ingredientes
// comprados) do que há para PRODUZIR (sub-receitas e ingredientes de fabrico
// próprio, pela receita-espelho). Devolve { comprar:{[ingId]:g},
// produzir:{[receitaId]:g} }.
// ---------------------------------------------------------------------------
function explodeProducao(app, receitaId, alvoG) {
  const num = (rec, f) => {
    try {
      return rec.getFloat(f);
    } catch (_) {
      return 0;
    }
  };
  const comprar = {};
  const produzir = {};
  const seen = new Set();

  const walk = (recId, alvo) => {
    if (seen.has(recId)) return;
    seen.add(recId);
    try {
      app.findRecordById('receitas', recId);
    } catch (_) {
      seen.delete(recId);
      return;
    }
    const itens = app.findRecordsByFilter(
      'itens_receita',
      'receita = {:id}',
      '',
      0,
      0,
      { id: recId },
    );
    let pesoBase = 0;
    for (const it of itens) pesoBase += num(it, 'quantidade_g') * fatorPesoLinha(app, it);
    const fator = pesoBase > 0 ? alvo / pesoBase : 0;
    for (const it of itens) {
      const g = num(it, 'quantidade_g') * fator;
      if (g <= 0) continue;
      const subRel = it.getString('sub_receita');
      const ingRel = it.getString('ingrediente');
      if (subRel) {
        produzir[subRel] = (produzir[subRel] || 0) + g;
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
          produzir[espelho] = (produzir[espelho] || 0) + g;
          walk(espelho, g);
        } else {
          comprar[ingRel] = (comprar[ingRel] || 0) + g;
        }
      }
    }
    seen.delete(recId);
  };

  walk(receitaId, alvoG);
  return { comprar: comprar, produzir: produzir };
}

// Explode "o que comprar" de uma linha de ficha (que aponta para uma receita
// OU para um ingrediente que pode ser um espelho de fabrico próprio).
function explodeComprasDe(app, alvo, receitaId, ingredienteId, porProduto) {
  if (receitaId) return explodeCompras(app, receitaId, alvo, porProduto);
  if (!ingredienteId) return {};
  let ing;
  try {
    ing = app.findRecordById('ingredientes', ingredienteId);
  } catch (_) {
    return {};
  }
  const espelho = ing.getString('receita_espelho');
  if (ing.getString('origem') === 'fabrico_proprio' && espelho) {
    return explodeCompras(app, espelho, alvo, porProduto);
  }
  const out = {};
  out[ingredienteId] = alvo;
  if (porProduto) {
    const b = (porProduto[ingredienteId] = porProduto[ingredienteId] || {});
    b[''] = (b[''] || 0) + alvo;
  }
  return out;
}

// ---------------------------------------------------------------------------
// Aplica um movimento de stock: upsert da linha `inventario` do item e cria
// um registo em `movimentos_inventario`. Devolve a quantidade final.
// item = { empresaId, ingredienteId? | fichaId? | consumivelId? | descricao?(item livre) }
// ---------------------------------------------------------------------------
function aplicarMovimento(app, item, delta, motivo, opts) {
  opts = opts || {};
  const livre =
    !item.ingredienteId && !item.fichaId && !item.consumivelId && item.descricao;
  const alvoCampo = item.ingredienteId
    ? 'ingrediente'
    : item.fichaId
      ? 'ficha'
      : item.consumivelId
        ? 'consumivel'
        : 'descricao';
  const alvoId =
    item.ingredienteId || item.fichaId || item.consumivelId || item.descricao;
  if (!alvoId) throw new BadRequestError('Falta ingrediente, ficha ou descrição.');

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
    if (livre && item.unidade) linha.set('unidade', item.unidade);
  }
  if (livre && item.categoria) linha.set('categoria', item.categoria);

  let q = linha.getFloat('quantidade') + delta;
  if (q < 0) q = 0;
  linha.set('quantidade', q);
  // "mais usados": conta quando o item é consumido/produzido numa produção.
  if (motivo === 'consumo_producao' || motivo === 'saida_producao') {
    linha.set('usos', linha.getFloat('usos') + 1);
    linha.set('ultimo_uso', new Date().toISOString());
  }
  app.save(linha);

  const mov = new Record(app.findCollectionByNameOrId('movimentos_inventario'));
  mov.set('empresa', item.empresaId);
  mov.set(alvoCampo, alvoId);
  if (livre && item.unidade) mov.set('unidade', item.unidade);
  if (livre && item.categoria) mov.set('categoria', item.categoria);
  mov.set('delta', delta);
  mov.set('motivo', motivo);
  if (opts.producaoId) mov.set('producao', opts.producaoId);
  if (opts.autorId) mov.set('autor', opts.autorId);
  if (opts.notas) mov.set('notas', opts.notas);
  app.save(mov);

  return q;
}

// Resolve a ficha técnica (produto acabado) correspondente a uma combinação
// massa + recheio + formato. Devolve o id da ficha ou '' se não houver.
//
// As fichas ligam a massa/recheio quer por `receita` quer pelo `ingrediente`
// espelho (o "ingrediente de fabrico próprio" cujo `receita_espelho` aponta para a
// receita) — os dois casos são aceites.
//
// O `formato` é usado como desempate: se houver fichas com o formato exato
// usa-se essa; senão aceita-se uma ficha SEM formato definido (fichas antigas).
// Só se descarta uma ficha com um formato *diferente* explicitamente definido.
function resolverFicha(app, empresaId, massaId, recheioId, formatoId) {
  if (!massaId) return '';
  const bool = (rec, f) => {
    try {
      return rec.getBool(f);
    } catch (_) {
      return false;
    }
  };
  // ids que representam uma receita numa ficha: a própria receita + os
  // ingredientes-espelho que apontam para ela.
  const refsDe = (recId) => {
    const out = [recId];
    if (!recId) return out;
    const esp = app.findRecordsByFilter(
      'ingredientes',
      'empresa = {:e} && receita_espelho = {:r}',
      '',
      0,
      0,
      { e: empresaId, r: recId },
    );
    for (const i of esp) out.push(i.id);
    return out;
  };
  const casa = (linha, refs) =>
    refs.indexOf(linha.getString('receita')) >= 0 ||
    refs.indexOf(linha.getString('ingrediente')) >= 0;

  const massaRefs = refsDe(massaId);
  const recheioRefs = recheioId ? refsDe(recheioId) : [];

  const linhasMassa = app.findRecordsByFilter(
    'itens_ficha',
    "empresa = {:e} && slot = 'massa'",
    '',
    0,
    0,
    { e: empresaId },
  );

  const exatas = [];
  const semFormato = [];
  const vistas = {};
  for (const lm of linhasMassa) {
    if (!casa(lm, massaRefs)) continue;
    const fichaId = lm.getString('ficha');
    if (!fichaId || vistas[fichaId]) continue;
    vistas[fichaId] = true;

    let ficha;
    try {
      ficha = app.findRecordById('fichas_tecnicas', fichaId);
    } catch (_) {
      continue;
    }
    if (bool(ficha, 'deletado')) continue;

    // recheio: só se o pedido indicar um recheio à mão (caminho sem ficha
    // pré-definida) é que exigimos correspondência num slot de recheio.
    // Sem recheio no pedido, os recheios da ficha são os que valem.
    if (recheioId) {
      const recheios = app.findRecordsByFilter(
        'itens_ficha',
        "ficha = {:f} && (slot = 'recheio_base' || slot = 'recheio_top')",
        '',
        0,
        0,
        { f: fichaId },
      );
      let ok = false;
      for (const r of recheios) {
        if (casa(r, recheioRefs)) {
          ok = true;
          break;
        }
      }
      if (!ok) continue;
    }

    const fFmt = ficha.getString('formato');
    if (formatoId && fFmt === formatoId) {
      exatas.push(fichaId);
    } else if (!fFmt) {
      semFormato.push(fichaId);
    }
    // fFmt definido e diferente do pedido -> ignora
  }

  if (exatas.length > 0) return exatas[0];
  if (semFormato.length > 0) return semFormato[0];
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

// Receita que uma linha de ficha representa: a própria `receita`, ou a
// receita-espelho de um ingrediente de fabrico próprio. '' se for um
// ingrediente comprado (ou vazio).
function receitaDaLinha(app, receitaId, ingredienteId) {
  if (receitaId) return receitaId;
  if (!ingredienteId) return '';
  try {
    const ing = app.findRecordById('ingredientes', ingredienteId);
    const esp = ing.getString('receita_espelho');
    return ing.getString('origem') === 'fabrico_proprio' && esp ? esp : '';
  } catch (_) {
    return '';
  }
}

// Dados de produção de uma ficha técnica (produto final): a massa que leva
// por unidade, qual é a receita dessa massa e o formato. `alvoG` (massa total
// a produzir) só serve para calcular as unidades. null se a ficha não existir
// ou não tiver massa.
function infoFicha(app, fichaId, alvoG) {
  if (!fichaId) return null;
  let ficha;
  try {
    ficha = app.findRecordById('fichas_tecnicas', fichaId);
  } catch (_) {
    return null;
  }
  const linhas = app.findRecordsByFilter(
    'itens_ficha',
    "ficha = {:f} && slot = 'massa'",
    '',
    0,
    0,
    { f: fichaId },
  );
  let massaG = 0;
  let massaReceitaId = '';
  for (const l of linhas) {
    let g = 0;
    try {
      g = l.getFloat('quantidade_g');
    } catch (_) {}
    if (g <= 0) continue;
    massaG += g;
    if (!massaReceitaId) {
      massaReceitaId = receitaDaLinha(
        app,
        l.getString('receita'),
        l.getString('ingrediente'),
      );
    }
  }
  if (massaG <= 0 || !massaReceitaId) return null;

  const formatoId = ficha.getString('formato');
  let formatoNome = '';
  if (formatoId) {
    try {
      formatoNome = app
        .findRecordById('formatos_cookie', formatoId)
        .getString('nome');
    } catch (_) {}
  }
  return {
    fichaId: fichaId,
    nome: ficha.getString('nome'),
    massaG: massaG,
    massaReceitaId: massaReceitaId,
    formatoId: formatoId,
    formatoNome: formatoNome,
    unidades: alvoG > 0 ? Math.round(alvoG / massaG) : 0,
  };
}

// Mise en place de um produto final: para `unidades` unidades da ficha,
// devolve { comprar:{[ingId]:g}, produzir:{[receitaId]:g} } — a massa, os
// recheios, as coberturas e extras (e as sub-receitas de cada um) a produzir
// primeiro, e os ingredientes crus a comprar/pesar.
function planoFicha(app, fichaId, unidades) {
  const info = infoFicha(app, fichaId, 0);
  if (!info) return null;
  const comprar = {};
  const produzir = {};
  const pp = {}; // {ingId: {produtoId|'': g}} — produtos fixados nas receitas
  const merge = (dst, src) => {
    for (const k in src) dst[k] = (dst[k] || 0) + src[k];
  };

  const linhas = app.findRecordsByFilter(
    'itens_ficha',
    'ficha = {:f}',
    '',
    0,
    0,
    { f: fichaId },
  );
  for (const l of linhas) {
    let g = 0;
    try {
      g = l.getFloat('quantidade_g') * unidades;
    } catch (_) {}
    if (g <= 0) continue;
    const recId = receitaDaLinha(
      app,
      l.getString('receita'),
      l.getString('ingrediente'),
    );
    if (recId) {
      produzir[recId] = (produzir[recId] || 0) + g;
      const ep = explodeProducao(app, recId, g);
      merge(comprar, ep.comprar);
      merge(produzir, ep.produzir);
      explodeCompras(app, recId, g, pp);
    } else if (l.getString('ingrediente')) {
      const ingId = l.getString('ingrediente');
      comprar[ingId] = (comprar[ingId] || 0) + g;
    }
  }
  return { info: info, comprar: comprar, produzir: produzir, produtosFixados: pp };
}

module.exports = {
  runCascade,
  fatorPesoIng,
  fatorPesoLinha,
  explodeCompras,
  explodeProducao,
  explodeComprasDe,
  aplicarMovimento,
  carregarProducao,
  resolverFicha,
  receitaDaLinha,
  infoFicha,
  planoFicha,
};
