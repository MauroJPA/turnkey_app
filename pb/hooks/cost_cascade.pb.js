/// <reference path="../pb_data/types.d.ts" />

// M4 — Ligações de eventos do motor de cascata de custos.
//
// NOTA: no PocketBase, o corpo de cada handler corre isolado e NÃO enxerga
// funções/constantes de topo deste ficheiro. Por isso cada handler é
// autocontido e a lógica pesada vem de cascade.js via require().

onRecordAfterUpdateSuccess((e) => {
  try {
    const EPS = 0.001;
    const num = (rec, f) => {
      try {
        return rec.getFloat(f);
      } catch (_) {
        return 0;
      }
    };
    const lst = (rec, f) => {
      try {
        const v = rec.get(f);
        if (Array.isArray(v)) return v.map(String).slice().sort().join('|');
        if (typeof v === 'string') return v;
      } catch (_) {}
      return '';
    };
    const before = e.record.original();
    const NUTRI = [
      'nutri_energia_kcal', 'nutri_lipidos_g', 'nutri_saturados_g',
      'nutri_hidratos_g', 'nutri_acucares_g', 'nutri_fibra_g',
      'nutri_proteina_g', 'nutri_sal_g', 'nutri_densidade',
    ];
    let mudou =
      Math.abs(num(e.record, 'preco') - num(before, 'preco')) > EPS ||
      Math.abs(
        num(e.record, 'gramas_embalagem') - num(before, 'gramas_embalagem'),
      ) > EPS;
    if (!mudou) {
      for (const f of NUTRI) {
        if (Math.abs(num(e.record, f) - num(before, f)) > 1e-6) {
          mudou = true;
          break;
        }
      }
    }
    if (
      !mudou &&
      (e.record.getString('nutri_base') !== before.getString('nutri_base') ||
        e.record.getBool('nutri_irrelevante') !==
          before.getBool('nutri_irrelevante') ||
        lst(e.record, 'alergenios') !== lst(before, 'alergenios') ||
        lst(e.record, 'alergenios_tracos') !==
          lst(before, 'alergenios_tracos'))
    ) {
      mudou = true;
    }
    if (mudou) {
      // alerta de variação de preço: foto das fichas antes da cascata...
      let foto = null;
      let vp = null;
      const precoMudou =
        Math.abs(num(e.record, 'preco') - num(before, 'preco')) > EPS ||
        Math.abs(
          num(e.record, 'gramas_embalagem') - num(before, 'gramas_embalagem'),
        ) > EPS;
      if (precoMudou) {
        try {
          vp = require(`${__hooks}/variacoes_preco.js`);
          foto = vp.fotografar(e.app, e.record);
        } catch (err) {
          console.log('[variacoes] foto: ' + err);
        }
      }
      require(`${__hooks}/cascade.js`).runCascade(
        e.app,
        'ingrediente',
        e.record.id,
      );
      // ... e comparação depois (nunca bloqueia a cascata)
      if (vp && foto) {
        try {
          vp.registar(e.app, e.record, before, foto);
        } catch (err) {
          console.log('[variacoes] registo: ' + err);
        }
      }
    }
  } catch (err) {
    console.log('[cascata] ingrediente: ' + err);
  }
  e.next();
}, 'ingredientes');

function aoMudarLinha(e) {
  try {
    const rid = e.record.getString('receita');
    if (rid) {
      require(`${__hooks}/cascade.js`).runCascade(e.app, 'receita', rid);
    }
  } catch (err) {
    console.log('[cascata] linha: ' + err);
  }
  e.next();
}

onRecordAfterCreateSuccess(aoMudarLinha, 'itens_receita');
onRecordAfterUpdateSuccess(aoMudarLinha, 'itens_receita');
onRecordAfterDeleteSuccess(aoMudarLinha, 'itens_receita');

function aoMudarLinhaFicha(e) {
  try {
    const fid = e.record.getString('ficha');
    if (fid) {
      require(`${__hooks}/cascade.js`).runCascade(e.app, 'ficha', fid);
    }
  } catch (err) {
    console.log('[cascata] linha ficha: ' + err);
  }
  e.next();
}

onRecordAfterCreateSuccess(aoMudarLinhaFicha, 'itens_ficha');
onRecordAfterUpdateSuccess(aoMudarLinhaFicha, 'itens_ficha');
onRecordAfterDeleteSuccess(aoMudarLinhaFicha, 'itens_ficha');

// Embalagens: ao mudar o custo (preço / peças / rendimento), atualiza o cache
// `custo_unitario` e re-corre as fichas que a usam.
onRecordAfterCreateSuccess((e) => {
  try {
    require(`${__hooks}/cascade.js`).runCascade(e.app, 'embalagem', e.record.id);
  } catch (err) {
    console.log('[cascata] embalagem: ' + err);
  }
  e.next();
}, 'embalagens');

onRecordAfterUpdateSuccess((e) => {
  try {
    const EPS = 0.001;
    const num = (rec, f) => {
      try {
        return rec.getFloat(f);
      } catch (_) {
        return 0;
      }
    };
    const b = e.record.original();
    const mudou =
      Math.abs(num(e.record, 'preco_compra') - num(b, 'preco_compra')) > EPS ||
      Math.abs(
        num(e.record, 'unidades_compra') - num(b, 'unidades_compra'),
      ) > EPS ||
      Math.abs(
        num(e.record, 'rende_unidades') - num(b, 'rende_unidades'),
      ) > EPS;
    if (mudou) {
      require(`${__hooks}/cascade.js`).runCascade(
        e.app,
        'embalagem',
        e.record.id,
      );
    }
  } catch (err) {
    console.log('[cascata] embalagem: ' + err);
  }
  e.next();
}, 'embalagens');

// Kits de embalagens: ao mudar as linhas do kit, recalcula o custo do kit
// (cache) e as fichas que o usam.
function aoMudarLinhaKit(e) {
  try {
    const kid = e.record.getString('kit');
    if (kid) {
      require(`${__hooks}/cascade.js`).runCascade(e.app, 'kit', kid);
    }
  } catch (err) {
    console.log('[cascata] linha kit: ' + err);
  }
  e.next();
}

onRecordAfterCreateSuccess(aoMudarLinhaKit, 'embalagem_kit_itens');
onRecordAfterUpdateSuccess(aoMudarLinhaKit, 'embalagem_kit_itens');
onRecordAfterDeleteSuccess(aoMudarLinhaKit, 'embalagem_kit_itens');

onRecordAfterUpdateSuccess((e) => {
  try {
    const EPS = 0.001;
    const num = (rec, f) => {
      try {
        return rec.getFloat(f);
      } catch (_) {
        return 0;
      }
    };
    const r = e.record;
    const before = r.original();
    const relevante =
      r.getBool('publicar_como_ingrediente') !==
        before.getBool('publicar_como_ingrediente') ||
      r.getBool('rendimento_manual') !== before.getBool('rendimento_manual') ||
      Math.abs(
        num(r, 'rendimento_esperado') - num(before, 'rendimento_esperado'),
      ) > EPS ||
      Math.abs(
        num(r, 'perda_cozedura_pct') - num(before, 'perda_cozedura_pct'),
      ) > EPS;
    if (relevante) {
      require(`${__hooks}/cascade.js`).runCascade(e.app, 'receita', r.id);
    }
  } catch (err) {
    console.log('[cascata] receita: ' + err);
  }
  e.next();
}, 'receitas');

// Revenda (Inventário → Limpeza e insumos: bebidas…): ao mudar o preço por
// unidade de um consumível, re-corre as fichas que o usam (2.22.1).
onRecordAfterUpdateSuccess((e) => {
  try {
    const num = (rec, f) => {
      try {
        return rec.getFloat(f);
      } catch (_) {
        return 0;
      }
    };
    if (Math.abs(num(e.record, 'preco') - num(e.record.original(), 'preco')) > 0.0001) {
      require(`${__hooks}/cascade.js`).runCascade(e.app, 'consumivel', e.record.id);
    }
  } catch (err) {
    console.log('[cascata] consumível: ' + err);
  }
  e.next();
}, 'consumiveis');
