/// <reference path="../pb_data/types.d.ts" />

// Rasto das alterações às faturas feitas pelas pessoas (pela API): fornecedor,
// número, data, totais, e apagar/restaurar. Guarda no `historico`
// (entidade_tipo = 'fatura', entidade_id = id da fatura) os valores antes e depois
// e quem fez. Apagar = `apagada = true` (a fatura e o ficheiro ficam na base de
// dados e nos backups). As alterações do servidor (análise da IA, aplicar) não
// passam por aqui.
//
// O fornecedor só se confirma UMA VEZ por fatura (todas as linhas são do
// mesmo fornecedor) — por isso, ao corrigir o fornecedor aqui, a alteração
// propaga-se a todos os produtos/consumíveis/embalagens que esta fatura já
// tocou (via `faturas_itens`), substituindo sempre o valor antigo (é uma
// correção explícita do proprietário).
//
// NOTA: cada handler é autocontido (os handlers correm isolados).

onRecordUpdateRequest((e) => {
  const CAMPOS = ['fornecedor', 'numero', 'data_fatura', 'total', 'iva', 'apagada'];
  const NOMES = {
    fornecedor: 'fornecedor',
    numero: 'nº',
    data_fatura: 'data',
    total: 'total',
    iva: 'IVA',
  };
  let antes = null;
  try {
    antes = e.record.original();
  } catch (_) {}
  const valor = (r, c) => {
    if (c === 'apagada') return r.getBool(c);
    if (c === 'total' || c === 'iva') return Math.round(r.getFloat(c) * 100) / 100;
    if (c === 'data_fatura') return String(r.getString(c) || '').substring(0, 10);
    return String(r.getString(c) || '');
  };
  const antesV = {};
  const depoisV = {};
  if (antes) {
    for (const c of CAMPOS) {
      const a = valor(antes, c);
      const d = valor(e.record, c);
      if (a !== d) {
        antesV[c] = a;
        depoisV[c] = d;
      }
    }
  }
  const auth = e.auth;
  const quem = auth
    ? auth.getString('nome') || auth.getString('email') || auth.id
    : '';
  if (depoisV.apagada === true) {
    e.record.set('apagada_em', new Date().toISOString());
    e.record.set('apagada_por', quem);
  } else if (depoisV.apagada === false) {
    e.record.set('apagada_em', '');
    e.record.set('apagada_por', '');
  }

  e.next();

  if (!Object.keys(depoisV).length) return;

  let fornecedorPropagadoPara = 0;
  if ('fornecedor' in depoisV) {
    try {
      const f = e.record;
      const empresaId = f.getString('empresa');
      const novoFornecedor = depoisV.fornecedor;
      const itens = e.app.findRecordsByFilter('faturas_itens', 'fatura = {:f}', '', 0, 0, { f: f.id });
      const vistos = {};
      for (const it of itens) {
        const produtoId = it.getString('produto');
        const consId = it.getString('consumivel');
        const embId = it.getString('embalagem');
        let colecao = '';
        let alvoId = '';
        if (produtoId) {
          colecao = 'ingrediente_produtos';
          alvoId = produtoId;
        } else if (consId) {
          colecao = 'consumiveis';
          alvoId = consId;
        } else if (embId) {
          colecao = 'embalagens';
          alvoId = embId;
        } else {
          continue;
        }
        const chave = colecao + ':' + alvoId;
        if (!vistos[chave]) {
          vistos[chave] = true;
          try {
            const alvo = e.app.findRecordById(colecao, alvoId);
            if (alvo.getString('empresa') === empresaId) {
              alvo.set('fornecedor', novoFornecedor);
              e.app.save(alvo);
              fornecedorPropagadoPara++;
            }
          } catch (_) {}
        }
        it.set('fornecedor', novoFornecedor);
        e.app.save(it);
      }
    } catch (err) {
      console.log('[faturas_edicao] propagar fornecedor: ' + err);
    }
  }

  try {
    const f = e.record;
    const partes = [];
    if (depoisV.apagada === true) partes.push('apagada');
    else if (depoisV.apagada === false) partes.push('restaurada');
    for (const c of Object.keys(NOMES)) {
      if (c in depoisV) partes.push(NOMES[c] + ': "' + antesV[c] + '" → "' + depoisV[c] + '"');
    }
    if (fornecedorPropagadoPara > 0) {
      partes.push('fornecedor atualizado em ' + fornecedorPropagadoPara + ' registo(s) já ligados a esta fatura');
    }
    const ref = [
      f.getString('fornecedor') || 'Fornecedor?',
      f.getString('numero') ? 'nº ' + f.getString('numero') : null,
    ].filter(Boolean).join(' ');
    const h = new Record(e.app.findCollectionByNameOrId('historico'));
    h.set('empresa', f.getString('empresa'));
    h.set('entidade_tipo', 'fatura');
    h.set('entidade_id', f.id);
    h.set('descricao', ('Fatura ' + ref + ' — ' + partes.join('; ') + (quem ? ' (por ' + quem + ')' : '')).substring(0, 500));
    h.set('valor_antes', antesV);
    h.set('valor_depois', depoisV);
    if (auth && auth.collection().name === 'users') h.set('autor', auth.id);
    e.app.save(h);
  } catch (err) {
    console.log('[faturas_edicao] ' + err);
  }
}, 'faturas');
