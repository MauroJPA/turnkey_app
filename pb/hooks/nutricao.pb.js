/// <reference path="../pb_data/types.d.ts" />

// Nutrição — endpoints:
//
//   POST /api/turnkey/ingredientes/{id}/rotulo   { imagem(base64), mime }
//   -> preenche os campos nutri_* + alergénios do ingrediente e devolve-os.
//
//   POST /api/turnkey/ingredientes/auto-insa   { ids?: string[], dryRun?: bool }
//   -> emparelha cada ingrediente (por omissão: os sem nutrição) com a tabela
//      INSA por semelhança de nome. Se houver um candidato claro, preenche
//      nutri_* + alergénios (origem 'insa'); se houver dúvida, marca
//      nutri_origem='insa_revisao' e devolve os candidatos mais próximos.
//      `dryRun` só devolve candidatos, não escreve nada.
//
// A chave da IA vive só no servidor (ver ai.js). O cálculo em cascata das
// receitas/fichas dispara sozinho (cost_cascade.pb.js deteta a mudança).

routerAdd(
  'POST',
  '/api/turnkey/ingredientes/{id}/rotulo',
  (e) => {
    const auth = e.auth;
    const isSuper =
      auth && auth.collection() && auth.collection().name === '_superusers';
    const id = e.request.pathValue('id');
    const ing = e.app.findRecordById('ingredientes', id);

    if (!isSuper) {
      if (!auth || auth.collection().name !== 'users') {
        throw new ForbiddenError('Autenticação necessária.');
      }
      if (auth.getString('empresa') !== ing.getString('empresa')) {
        throw new ForbiddenError('Ingrediente de outra empresa.');
      }
      if (auth.getString('papel') === 'viewer') {
        throw new ForbiddenError('Sem permissão.');
      }
    }

    const body = e.requestInfo().body || {};
    const imagem = (body.imagem || '').toString();
    const mime = (body.mime || 'image/jpeg').toString();
    if (!imagem) throw new BadRequestError('Falta a imagem (base64).');

    const r = require(`${__hooks}/ai.js`).analisarImagemIA({
      imagemBase64: imagem,
      mime: mime,
      tarefa: 'rotulo',
    });
    if (!r.ok) {
      if (r.code === 503) throw new ApiError(503, r.message, null);
      throw new ApiError(502, r.message, null);
    }

    const nr = require(`${__hooks}/nutri_rotulo.js`).normalizarRotulo(r.dados);
    const n = nr.nutri;
    const alerg = nr.alergenios;
    const tracos = nr.alergenios_tracos;

    ing.set('nutri_energia_kcal', n.energia_kcal);
    ing.set('nutri_lipidos_g', n.lipidos_g);
    ing.set('nutri_saturados_g', n.saturados_g);
    ing.set('nutri_hidratos_g', n.hidratos_g);
    ing.set('nutri_acucares_g', n.acucares_g);
    ing.set('nutri_fibra_g', n.fibra_g);
    ing.set('nutri_proteina_g', n.proteina_g);
    ing.set('nutri_sal_g', n.sal_g);
    ing.set('nutri_base', nr.base);
    if (nr.densidade > 0 && nr.densidade !== 1) {
      ing.set('nutri_densidade', nr.densidade);
    }
    ing.set('nutri_origem', 'rotulo');
    ing.set('nutri_atualizado_em', new Date().toISOString());
    ing.set('alergenios', alerg);
    ing.set('alergenios_tracos', tracos);
    e.app.save(ing);

    return e.json(200, {
      provider: r.provider,
      nutri: {
        energia_kcal: ing.getFloat('nutri_energia_kcal'),
        lipidos_g: ing.getFloat('nutri_lipidos_g'),
        saturados_g: ing.getFloat('nutri_saturados_g'),
        hidratos_g: ing.getFloat('nutri_hidratos_g'),
        acucares_g: ing.getFloat('nutri_acucares_g'),
        fibra_g: ing.getFloat('nutri_fibra_g'),
        proteina_g: ing.getFloat('nutri_proteina_g'),
        sal_g: ing.getFloat('nutri_sal_g'),
      },
      base: ing.getString('nutri_base'),
      alergenios: alerg,
      alergenios_tracos: tracos,
      ingredientes_texto: nr.ingredientes_texto,
    });
  },
  $apis.requireAuth('users', '_superusers'),
);

// --- POST /api/turnkey/nutricao/ler-rotulo -------------------------------
// Lê um rótulo por IA SEM gravar nada (usado ao criar um ingrediente, que
// ainda não existe). Body { imagem(base64), mime } -> valores por 100 g/ml.
routerAdd(
  'POST',
  '/api/turnkey/nutricao/ler-rotulo',
  (e) => {
    const auth = e.auth;
    const isSuper =
      auth && auth.collection() && auth.collection().name === '_superusers';
    if (!isSuper) {
      if (!auth || auth.collection().name !== 'users') {
        throw new ForbiddenError('Autenticação necessária.');
      }
      if (auth.getString('papel') === 'viewer') {
        throw new ForbiddenError('Sem permissão.');
      }
    }
    const body = e.requestInfo().body || {};
    const imagem = (body.imagem || '').toString();
    const mime = (body.mime || 'image/jpeg').toString();
    if (!imagem) throw new BadRequestError('Falta a imagem (base64).');

    const r = require(`${__hooks}/ai.js`).analisarImagemIA({
      imagemBase64: imagem,
      mime: mime,
      tarefa: 'rotulo',
    });
    if (!r.ok) {
      if (r.code === 503) throw new ApiError(503, r.message, null);
      throw new ApiError(502, r.message, null);
    }
    const nr = require(`${__hooks}/nutri_rotulo.js`).normalizarRotulo(r.dados);
    return e.json(200, {
      provider: r.provider,
      nutri: nr.nutri,
      base: nr.base,
      densidade: nr.densidade,
      alergenios: nr.alergenios,
      alergenios_tracos: nr.alergenios_tracos,
      ingredientes_texto: nr.ingredientes_texto,
    });
  },
  $apis.requireAuth('users', '_superusers'),
);

routerAdd(
  'POST',
  '/api/turnkey/ingredientes/auto-insa',
  (e) => {
    const auth = e.auth;
    const isSuper =
      auth && auth.collection() && auth.collection().name === '_superusers';
    if (!isSuper) {
      if (!auth || auth.collection().name !== 'users') {
        throw new ForbiddenError('Autenticação necessária.');
      }
      if (auth.getString('papel') === 'viewer') {
        throw new ForbiddenError('Sem permissão.');
      }
    }
    const empresaId = isSuper ? '' : auth.getString('empresa');

    const body = e.requestInfo().body || {};
    const dryRun = body.dryRun === true;
    const idsPedidos = Array.isArray(body.ids)
      ? body.ids.map((x) => String(x)).filter(Boolean)
      : null;

    const ALERGENIOS = [
      'Glúten', 'Crustáceos', 'Ovos', 'Peixe', 'Amendoins', 'Soja', 'Leite',
      'Frutos de casca rija', 'Aipo', 'Mostarda', 'Sésamo', 'Sulfitos',
      'Tremoço', 'Moluscos',
    ];
    const semAcentos = (s) => {
      const m = {
        'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a', 'ä': 'a',
        'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
        'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
        'ó': 'o', 'ò': 'o', 'õ': 'o', 'ô': 'o', 'ö': 'o',
        'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ç': 'c',
      };
      let o = String(s).toLowerCase();
      for (const k in m) o = o.split(k).join(m[k]);
      return o;
    };
    const tokens = (s) => {
      const raw = semAcentos(s).replace(/[^a-z0-9 ]/g, ' ').split(/\s+/);
      const out = [];
      for (const t of raw) if (t.length > 2 && out.indexOf(t) < 0) out.push(t);
      return out;
    };
    // --- carregar ingredientes-alvo ---------------------------------
    let alvos;
    if (idsPedidos) {
      alvos = [];
      for (const id of idsPedidos) {
        try {
          const r = e.app.findRecordById('ingredientes', id);
          if (!isSuper && r.getString('empresa') !== empresaId) continue;
          alvos.push(r);
        } catch (_) {}
      }
    } else {
      const filtro = isSuper
        ? "nutri_energia_kcal = 0 && nutri_proteina_g = 0 && deletado = false"
        : "empresa = {:emp} && nutri_energia_kcal = 0 && " +
          "nutri_proteina_g = 0 && deletado = false";
      alvos = e.app.findRecordsByFilter(
        'ingredientes', filtro, 'nome', 500, 0, { emp: empresaId },
      );
    }

    // --- carregar a tabela INSA uma vez ----------------------------
    const refs = e.app.findRecordsByFilter(
      'ingredientes_referencia', "id != ''", 'nome', 0, 0, {},
    );
    const idx = [];
    for (const r of refs) {
      idx.push({
        rec: r,
        toks: tokens(r.getString('nome')),
      });
    }

    const nutriDe = (r) => ({
      energia_kcal: r.getFloat('nutri_energia_kcal'),
      lipidos_g: r.getFloat('nutri_lipidos_g'),
      saturados_g: r.getFloat('nutri_saturados_g'),
      hidratos_g: r.getFloat('nutri_hidratos_g'),
      acucares_g: r.getFloat('nutri_acucares_g'),
      fibra_g: r.getFloat('nutri_fibra_g'),
      proteina_g: r.getFloat('nutri_proteina_g'),
      sal_g: r.getFloat('nutri_sal_g'),
    });
    const alergDe = (r) => {
      const v = r.get('alergenios');
      const out = [];
      for (const a of Array.isArray(v) ? v : []) {
        if (ALERGENIOS.indexOf(a) >= 0 && out.indexOf(a) < 0) out.push(a);
      }
      return out;
    };

    const resultados = [];
    let aplicados = 0;

    const nomeNorm = (s) =>
      semAcentos(s).replace(/[^a-z0-9 ]/g, ' ').replace(/\s+/g, ' ').trim();

    for (const ing of alvos) {
      const alvoNome = ing.getString('nome') + ' ' + ing.getString('caracteristica');
      const alvoToks = tokens(alvoNome);
      const alvoN = nomeNorm(ing.getString('nome'));
      const pont = [];
      for (const cand of idx) {
        const rt = cand.toks;
        if (!alvoToks.length || !rt.length) continue;
        let inter = 0;
        for (const t of alvoToks) if (rt.indexOf(t) >= 0) inter++;
        if (inter === 0) continue;
        const recall = inter / alvoToks.length; // do alvo, quanto foi coberto
        const precision = inter / rt.length; // da referência, quanto é útil
        let s = 0.5 * recall + 0.5 * precision;
        if (rt[0] === alvoToks[0]) s += 0.2; // mesma palavra-cabeça
        const cn = nomeNorm(cand.rec.getString('nome'));
        if (cn === alvoN) s += 0.5;
        else if (cn.indexOf(alvoN) === 0 || alvoN.indexOf(cn) === 0) s += 0.15;
        if (rt.length - inter >= 3) s -= 0.1; // referência muito "diluída"
        pont.push({ cand: cand, score: s });
      }
      pont.sort((a, b) => b.score - a.score);
      const top = pont.slice(0, 6).map((p) => {
        const r = p.cand.rec;
        return {
          id: r.id,
          nome: r.getString('nome'),
          grupo: r.getString('grupo'),
          score: Math.round(p.score * 100) / 100,
          nutri: nutriDe(r),
          alergenios: alergDe(r),
        };
      });

      const best = pont[0] ? pont[0].score : 0;
      const second = pont[1] ? pont[1].score : 0;
      // confiante só quando há um vencedor destacado — se dois candidatos
      // ficam perto (ex.: "Farinha de trigo T55" vs "...integral"), manda
      // para revisão e deixa a pessoa escolher.
      const confiante = best >= 0.8 && best - second >= 0.2;

      if (top.length === 0 || best < 0.3) {
        if (!dryRun) {
          const o0 = ing.getString('nutri_origem');
          if (!o0 || o0 === 'insa_revisao') {
            ing.set('nutri_origem', 'insa_revisao');
            e.app.save(ing);
          }
        }
        resultados.push({
          ingredienteId: ing.id,
          nome: ing.getString('nome'),
          estado: 'sem_candidato',
          candidatos: top,
        });
        continue;
      }

      if (!dryRun && confiante) {
        const r = pont[0].cand.rec;
        const n = nutriDe(r);
        ing.set('nutri_energia_kcal', n.energia_kcal);
        ing.set('nutri_lipidos_g', n.lipidos_g);
        ing.set('nutri_saturados_g', n.saturados_g);
        ing.set('nutri_hidratos_g', n.hidratos_g);
        ing.set('nutri_acucares_g', n.acucares_g);
        ing.set('nutri_fibra_g', n.fibra_g);
        ing.set('nutri_proteina_g', n.proteina_g);
        ing.set('nutri_sal_g', n.sal_g);
        ing.set('nutri_base', '100g');
        ing.set('nutri_origem', 'insa');
        ing.set('nutri_atualizado_em', new Date().toISOString());
        ing.set('alergenios', alergDe(r));
        e.app.save(ing);
        aplicados++;
        resultados.push({
          ingredienteId: ing.id,
          nome: ing.getString('nome'),
          estado: 'preenchido',
          referencia: { id: r.id, nome: r.getString('nome'), score: top[0].score },
          candidatos: top,
        });
        continue;
      }

      // dúvida -> marcar para revisão (sem estragar origem manual/rótulo/insa)
      if (!dryRun) {
        const o = ing.getString('nutri_origem');
        if (!o || o === 'insa_revisao') {
          ing.set('nutri_origem', 'insa_revisao');
          e.app.save(ing);
        }
      }
      resultados.push({
        ingredienteId: ing.id,
        nome: ing.getString('nome'),
        estado: 'revisao',
        candidatos: top,
      });
    }

    return e.json(200, {
      aplicados: aplicados,
      total: alvos.length,
      resultados: resultados,
    });
  },
  $apis.requireAuth('users', '_superusers'),
);
