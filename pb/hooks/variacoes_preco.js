// Alerta de variação de preço (módulo partilhado via require()).
//
// `fotografar` guarda o custo de todas as fichas ANTES da cascata e `registar`
// compara DEPOIS: as fichas cujo custo mudou ficam na variação.

function precoKg(rec) {
  const p = rec.getFloat('preco') || 0;
  const g = rec.getFloat('gramas_embalagem') || 0;
  return g > 0 ? (p / g) * 1000 : p;
}

function lerFichas(app, empresaId) {
  const recs = app.findRecordsByFilter('fichas_tecnicas', 'empresa = {:e}', '', 0, 0, { e: empresaId });
  const m = {};
  for (const r of recs) {
    if (r.getBool('deletado')) continue;
    m[r.id] = {
      nome: r.getString('nome'),
      custo: r.getFloat('custo_produto') || 0,
      venda: r.getFloat('preco_venda') || 0,
    };
  }
  return m;
}

function fotografar(app, ingrediente) {
  return lerFichas(app, ingrediente.getString('empresa'));
}

function registar(app, ingrediente, antesRec, foto) {
  const antes = precoKg(antesRec);
  const depois = precoKg(ingrediente);
  if (!(antes > 0) || !(depois > 0)) return null;
  const pct = (depois / antes - 1) * 100;
  if (Math.abs(pct) < 1) return null;

  const empresaId = ingrediente.getString('empresa');
  const agora = lerFichas(app, empresaId);
  const afetadas = [];
  for (const id in agora) {
    const a = foto && foto[id];
    if (!a) continue;
    if (Math.abs(agora[id].custo - a.custo) > 0.0001) {
      afetadas.push({
        id: id,
        nome: agora[id].nome,
        custo_antes: a.custo,
        custo_depois: agora[id].custo,
        preco_venda: agora[id].venda,
      });
    }
  }
  const col = app.findCollectionByNameOrId('variacoes_preco');
  const rec = new Record(col);
  rec.set('empresa', empresaId);
  rec.set('ingrediente', ingrediente.id);
  rec.set('ingrediente_nome', ingrediente.getString('nome'));
  rec.set('antes', antes);
  rec.set('depois', depois);
  rec.set('pct', pct);
  rec.set('afetadas', afetadas);
  app.save(rec);

  // limpeza: guarda ~4 meses
  try {
    const limite = new Date(Date.now() - 120 * 24 * 3600 * 1000).toISOString().replace('T', ' ');
    const velhas = app.findRecordsByFilter('variacoes_preco', 'empresa = {:e} && created < {:l}', '', 200, 0, {
      e: empresaId,
      l: limite,
    });
    for (const v of velhas) app.delete(v);
  } catch (_) {}
  return rec;
}

module.exports = { fotografar, registar, precoKg };
