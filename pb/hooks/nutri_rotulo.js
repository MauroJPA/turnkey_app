// Interpretação da resposta da IA para um rótulo nutricional — partilhada pelo
// endpoint que grava no ingrediente e pelo que só lê (criação de ingrediente).

const VALIDOS = [
  'Glúten', 'Crustáceos', 'Ovos', 'Peixe', 'Amendoins', 'Soja', 'Leite',
  'Frutos de casca rija', 'Aipo', 'Mostarda', 'Sésamo', 'Sulfitos',
  'Tremoço', 'Moluscos',
];

const num = (v) => {
  const x = Number(v);
  return isFinite(x) && x >= 0 ? x : 0;
};

// só os 14 alergénios válidos (case-insensitive), sem repetidos
function canon(arr) {
  const out = [];
  for (const a of Array.isArray(arr) ? arr : []) {
    const s = String(a).toLowerCase().trim();
    for (const v of VALIDOS) {
      if (v.toLowerCase() === s && out.indexOf(v) < 0) out.push(v);
    }
  }
  return out;
}

// dados = `r.dados` devolvido por ai.analisarImagemIA (tarefa 'rotulo')
function normalizarRotulo(dados) {
  const d = dados || {};
  const n = d.nutri || {};
  const alergenios = canon(d.alergenios);
  const tracos = canon(d.alergenios_tracos).filter(
    (t) => alergenios.indexOf(t) < 0,
  );
  return {
    nutri: {
      energia_kcal: num(n.energia_kcal),
      lipidos_g: num(n.lipidos_g),
      saturados_g: num(n.saturados_g),
      hidratos_g: num(n.hidratos_g),
      acucares_g: num(n.acucares_g),
      fibra_g: num(n.fibra_g),
      proteina_g: num(n.proteina_g),
      sal_g: num(n.sal_g),
    },
    base: d.base === '100ml' ? '100ml' : '100g',
    densidade: d.densidade && Number(d.densidade) > 0 ? Number(d.densidade) : 1,
    alergenios: alergenios,
    alergenios_tracos: tracos,
    ingredientes_texto: d.ingredientes_texto || '',
  };
}

module.exports = { normalizarRotulo, canon, VALIDOS };
