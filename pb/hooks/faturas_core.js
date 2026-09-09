/// <reference path="../pb_data/types.d.ts" />

// Núcleo da análise de uma fatura por IA — partilhado pelo endpoint
// POST /api/turnkey/faturas/{id}/analisar e pelo cron de ingestão do scanner.
//
//   analisarFatura(app, faturaId, { imagemBase64, mime })
//     -> { ok:true, provider, dados }
//     -> { ok:false, code, message, duplicadaDe? }   (503 sem chave; 502
//        rede/IA; 409 duplicada; 4xx dados em falta). Para 502/409 a fatura
//        fica em `estado='erro'` (503 não mexe).

function analisarFatura(app, faturaId, opts) {
  let fatura;
  try {
    fatura = app.findRecordById('faturas', faturaId);
  } catch (_) {
    return { ok: false, code: 404, message: 'Fatura não encontrada.' };
  }
  const empresaId = fatura.getString('empresa');
  const imagem = (opts && opts.imagemBase64) || '';
  const mime = (opts && opts.mime) || 'image/jpeg';
  if (!imagem) return { ok: false, code: 400, message: 'Falta a imagem (base64).' };

  const tipo = fatura.getString('tipo') || 'fatura';
  const isLista = tipo === 'lista_precos';

  const ai = require(`${__hooks}/ai.js`);
  const r = ai.analisarImagemIA({
    imagemBase64: imagem,
    mime: mime,
    tarefa: 'fatura',
    isLista: isLista,
  });

  if (!r.ok) {
    if (r.code === 503) return { ok: false, code: 503, message: r.message };
    fatura.set('estado', 'erro');
    fatura.set(
      'dados_ia',
      r.raw ? { erro: r.message, bruto: r.raw } : { erro: r.message },
    );
    app.save(fatura);
    return { ok: false, code: 502, message: r.message };
  }

  const dados = r.dados;

  // --- deteção de fatura duplicada (não se aplica a listas de preços) ----
  if (!isLista) {
    const forn = String(dados.fornecedor || fatura.getString('fornecedor') || '');
    const num = String(dados.numero || fatura.getString('numero') || '');
    const dataF = String(dados.data || fatura.getString('data_fatura') || '').substring(0, 10);
    const totalF =
      typeof dados.total === 'number' ? dados.total : fatura.getFloat('total');
    const norm = (s) =>
      String(s || '').toLowerCase().replace(/\s+/g, '').replace(/[^a-z0-9]/g, '');
    const fN = norm(forn);
    if (fN && (norm(num) || dataF)) {
      const candidatos = app.findRecordsByFilter(
        'faturas',
        "empresa = {:e} && id != {:id} && tipo = 'fatura' && estado != 'erro'",
        '',
        200,
        0,
        { e: empresaId, id: faturaId },
      );
      let dup = null;
      for (const c of candidatos) {
        if (norm(c.getString('fornecedor')) !== fN) continue;
        const cData = String(c.getString('data_fatura') || '').substring(0, 10);
        if (norm(num)) {
          if (
            norm(c.getString('numero')) === norm(num) &&
            (!dataF || !cData || cData === dataF)
          ) {
            dup = c;
            break;
          }
        } else if (
          dataF &&
          cData === dataF &&
          totalF > 0 &&
          Math.abs(c.getFloat('total') - totalF) < 0.01
        ) {
          dup = c;
          break;
        }
      }
      if (dup) {
        fatura.set('estado', 'erro');
        fatura.set('dados_ia', {
          erro:
            'Fatura duplicada: ja existe "' + (num || dataF) + '" de ' + forn + '.',
          duplicada_de: dup.id,
          linhas: dados.linhas || [],
        });
        app.save(fatura);
        return {
          ok: false,
          code: 409,
          message: 'Fatura duplicada de ' + forn + ' (' + (num || dataF) + ').',
          duplicadaDe: dup.id,
        };
      }
    }
  }

  fatura.set('dados_ia', dados);
  fatura.set('estado', 'analisada');
  if (!fatura.getString('fornecedor') && dados.fornecedor)
    fatura.set('fornecedor', String(dados.fornecedor));
  if (!fatura.getString('numero') && dados.numero)
    fatura.set('numero', String(dados.numero));
  if (!fatura.get('total') && typeof dados.total === 'number')
    fatura.set('total', dados.total);
  if (!fatura.get('iva') && typeof dados.iva === 'number')
    fatura.set('iva', dados.iva);
  if (!fatura.getString('data_fatura') && dados.data)
    fatura.set('data_fatura', String(dados.data));
  app.save(fatura);

  return { ok: true, provider: r.provider, dados: dados };
}

module.exports = { analisarFatura };
