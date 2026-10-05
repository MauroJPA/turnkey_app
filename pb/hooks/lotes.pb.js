/// <reference path="../pb_data/types.d.ts" />

// Rastreabilidade por lote: ajuda para registar um lote de produção.
//
//   GET /api/gc_turnkey/lotes/ingredientes?ficha=ID
//     -> { ingredientes: [{ id, nome, lotes: [{ id, lote, validade, fornecedor }] }] }
//   Os ingredientes que a ficha usa (diretos e, por receita/sub-receita, os de
//   dentro), cada um com os lotes conhecidos (os que vencem primeiro vêm antes).
//
// NOTA: cada handler corre isolado — a recursão vive dentro do handler.

routerAdd(
  'GET',
  '/api/gc_turnkey/lotes/ingredientes',
  (e) => {
    const auth = e.auth;
    if (!auth || auth.collection().name !== 'users' || !auth.getString('empresa')) {
      throw new ForbiddenError('Autenticação necessária.');
    }
    const empresaId = auth.getString('empresa');
    const fichaId = String(e.request.url.query().get('ficha') || '');
    if (!fichaId) throw new BadRequestError('ficha em falta.');
    let ficha;
    try {
      ficha = e.app.findRecordById('fichas_tecnicas', fichaId);
    } catch (_) {
      throw new NotFoundError('Ficha não encontrada.');
    }
    if (ficha.getString('empresa') !== empresaId) throw new NotFoundError('Ficha não encontrada.');

    const ids = {};
    const vistas = {};
    const juntarReceita = (receitaId, prof) => {
      if (!receitaId || vistas[receitaId] || prof > 8) return;
      vistas[receitaId] = true;
      const itens = e.app.findRecordsByFilter('itens_receita', 'receita = {:r}', '', 0, 0, { r: receitaId });
      for (const it of itens) {
        if (it.getString('ingrediente')) ids[it.getString('ingrediente')] = true;
        if (it.getString('sub_receita')) juntarReceita(it.getString('sub_receita'), prof + 1);
      }
    };
    const itensFicha = e.app.findRecordsByFilter('itens_ficha', 'ficha = {:f}', '', 0, 0, { f: fichaId });
    for (const it of itensFicha) {
      if (it.getString('ingrediente')) ids[it.getString('ingrediente')] = true;
      if (it.getString('receita')) juntarReceita(it.getString('receita'), 0);
    }

    const hoje = new Date().toISOString().substring(0, 10);
    const out = [];
    for (const id in ids) {
      let ing;
      try {
        ing = e.app.findRecordById('ingredientes', id);
      } catch (_) {
        continue;
      }
      if (ing.getString('empresa') !== empresaId) continue;
      const lotes = e.app.findRecordsByFilter('lotes_ingrediente', 'ingrediente = {:i}', '-created', 30, 0, { i: id });
      const lista = lotes.map((l) => ({
        id: l.id,
        lote: l.getString('lote'),
        validade: String(l.getString('validade') || '').substring(0, 10),
        fornecedor: l.getString('fornecedor'),
      }));
      // os que ainda não passaram da validade primeiro, por validade crescente
      lista.sort((a, b) => {
        const ea = a.validade && a.validade < hoje ? 1 : 0;
        const eb = b.validade && b.validade < hoje ? 1 : 0;
        if (ea !== eb) return ea - eb;
        return (a.validade || '9999').localeCompare(b.validade || '9999');
      });
      out.push({ id: id, nome: ing.getString('nome'), lotes: lista });
    }
    out.sort((a, b) => a.nome.localeCompare(b.nome));
    return e.json(200, { ingredientes: out });
  },
  $apis.requireAuth('users'),
);
