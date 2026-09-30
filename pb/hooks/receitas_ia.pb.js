/// <reference path="../pb_data/types.d.ts" />

// Leitura de receitas por IA — endpoint só de leitura, não grava nada: o
// Flutter usa o resultado para pré-preencher o nome + a lista de
// ingredientes antes de importar (revisão manual sempre, como as faturas e
// o rótulo nutricional — ver ai.js e nutricao.pb.js).
//
//   POST /api/gc_turnkey/receitas/ler-imagem   { imagem(base64), mime }
//   -> { provider, nome, categoria, ingredientes: [{nome, quantidade_g}] }

routerAdd(
  'POST',
  '/api/gc_turnkey/receitas/ler-imagem',
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
      tarefa: 'receita',
    });
    if (!r.ok) {
      if (r.code === 503) throw new ApiError(503, r.message, null);
      throw new ApiError(502, r.message, null);
    }

    const d = r.dados || {};
    const linhasIn = Array.isArray(d.ingredientes) ? d.ingredientes : [];
    const ingredientes = [];
    for (const l of linhasIn) {
      const nome = (l && l.nome ? String(l.nome) : '').trim();
      const qtd = Number(l && l.quantidade_g);
      if (!nome || !isFinite(qtd) || qtd <= 0) continue;
      ingredientes.push({ nome: nome, quantidade_g: qtd });
    }

    return e.json(200, {
      provider: r.provider,
      nome: (d.nome || '').toString().trim(),
      categoria: (d.categoria || '').toString().trim(),
      ingredientes: ingredientes,
    });
  },
  $apis.requireAuth('users', '_superusers'),
);
