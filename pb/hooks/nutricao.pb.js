/// <reference path="../pb_data/types.d.ts" />

// Nutrição — endpoint de leitura de rótulo por IA.
//
//   POST /api/turnkey/ingredientes/{id}/rotulo   { imagem(base64), mime }
//   -> preenche os campos nutri_* + alergénios do ingrediente e devolve-os.
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

    const d = r.dados || {};
    const n = d.nutri || {};
    const num = (v) => {
      const x = Number(v);
      return isFinite(x) && x >= 0 ? x : 0;
    };

    // alergénios: só os 14 válidos (case-insensitive)
    const VALIDOS = [
      'Glúten', 'Crustáceos', 'Ovos', 'Peixe', 'Amendoins', 'Soja', 'Leite',
      'Frutos de casca rija', 'Aipo', 'Mostarda', 'Sésamo', 'Sulfitos',
      'Tremoço', 'Moluscos',
    ];
    const canon = (arr) => {
      const out = [];
      for (const a of Array.isArray(arr) ? arr : []) {
        const s = String(a).toLowerCase().trim();
        for (const v of VALIDOS) {
          if (v.toLowerCase() === s && out.indexOf(v) < 0) out.push(v);
        }
      }
      return out;
    };
    const alerg = canon(d.alergenios);
    const tracos = canon(d.alergenios_tracos).filter(
      (t) => alerg.indexOf(t) < 0,
    );

    ing.set('nutri_energia_kcal', num(n.energia_kcal));
    ing.set('nutri_lipidos_g', num(n.lipidos_g));
    ing.set('nutri_saturados_g', num(n.saturados_g));
    ing.set('nutri_hidratos_g', num(n.hidratos_g));
    ing.set('nutri_acucares_g', num(n.acucares_g));
    ing.set('nutri_fibra_g', num(n.fibra_g));
    ing.set('nutri_proteina_g', num(n.proteina_g));
    ing.set('nutri_sal_g', num(n.sal_g));
    ing.set('nutri_base', d.base === '100ml' ? '100ml' : '100g');
    if (d.densidade && Number(d.densidade) > 0) {
      ing.set('nutri_densidade', Number(d.densidade));
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
      ingredientes_texto: d.ingredientes_texto || '',
    });
  },
  $apis.requireAuth('users', '_superusers'),
);
