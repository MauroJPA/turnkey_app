/// <reference path="../pb_data/types.d.ts" />

// Núcleo da análise de uma fatura por IA — partilhado pelo endpoint
// POST /api/gc_turnkey/faturas/{id}/analisar e pelo cron de ingestão do scanner.
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

  const lista = r.lista && r.lista.length ? r.lista : [r.dados];
  const norm = (x) =>
    String(x || '').toLowerCase().replace(/\s+/g, '').replace(/[^a-z0-9]/g, '');

  // Grava `dados` em `rec` (uma fatura). Devolve null se correu bem, ou a
  // descrição da duplicada (a fatura fica em erro).
  const aplicar = (rec, dados, sobrepor) => {
    if (!isLista) {
      const forn = String(dados.fornecedor || rec.getString('fornecedor') || '');
      const num = String(dados.numero || rec.getString('numero') || '');
      const dataF = String(dados.data || rec.getString('data_fatura') || '').substring(0, 10);
      const totalF = typeof dados.total === 'number' ? dados.total : rec.getFloat('total');
      const fN = norm(forn);
      if (fN && (norm(num) || dataF)) {
        const candidatos = app.findRecordsByFilter(
          'faturas',
          "empresa = {:e} && id != {:id} && tipo = 'fatura' && estado != 'erro'",
          '',
          200,
          0,
          { e: empresaId, id: rec.id },
        );
        let dup = null;
        for (const c of candidatos) {
          if (norm(c.getString('fornecedor')) !== fN) continue;
          const cData = String(c.getString('data_fatura') || '').substring(0, 10);
          if (norm(num)) {
            if (norm(c.getString('numero')) === norm(num) && (!dataF || !cData || cData === dataF)) {
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
          rec.set('estado', 'erro');
          rec.set('dados_ia', {
            erro: 'Fatura duplicada: ja existe "' + (num || dataF) + '" de ' + forn + '.',
            duplicada_de: dup.id,
            linhas: dados.linhas || [],
          });
          app.save(rec);
          return { dup: dup, message: 'Fatura duplicada de ' + forn + ' (' + (num || dataF) + ').' };
        }
      }
    }
    rec.set('dados_ia', dados);
    rec.set('estado', 'analisada');
    if ((sobrepor || !rec.getString('fornecedor')) && dados.fornecedor)
      rec.set('fornecedor', String(dados.fornecedor));
    if ((sobrepor || !rec.getString('numero')) && dados.numero)
      rec.set('numero', String(dados.numero));
    if ((sobrepor || !rec.get('total')) && typeof dados.total === 'number')
      rec.set('total', dados.total);
    if ((sobrepor || !rec.get('iva')) && typeof dados.iva === 'number')
      rec.set('iva', dados.iva);
    if ((sobrepor || !rec.getString('data_fatura')) && dados.data)
      rec.set('data_fatura', String(dados.data));
    app.save(rec);
    return null;
  };

  // --- um só documento (o caso normal) ------------------------------------
  if (lista.length === 1 || isLista) {
    const dup = aplicar(fatura, lista[0], false);
    if (dup) {
      return { ok: false, code: 409, message: dup.message, duplicadaDe: dup.dup.id };
    }
    return { ok: true, provider: r.provider, dados: lista[0], faturas: [faturaId], dividido: false };
  }

  // --- vários documentos no mesmo ficheiro ---------------------------------
  const nomeOrig = fatura.getString('ficheiro');
  const origem = nomeOrig
    ? String(app.dataDir()) + '/storage/' + fatura.baseFilesPath() + '/' + nomeOrig
    : '';
  // Corta o PDF em `lista.length` ficheiros (um por fatura) com o `qpdf`, segundo
  // as páginas que a IA indicou. Devolve um array de File (um por fatura) ou null
  // se não for PDF, se o qpdf não existir ou se as páginas não fizerem sentido
  // (nesse caso as faturas ficam com o ficheiro inteiro).
  const dividirPdf = function (app, origem, nomeOrig, lista) {
    let tmp = '';
    try {
      if (!origem || !/\.pdf$/i.test(nomeOrig)) return null;
      const n = parseInt(toString($os.cmd('qpdf', '--show-npages', origem).output()).trim(), 10);
      if (!(n >= 1)) return null;

      // páginas de cada fatura: inteiros dentro do PDF, sem repetir entre faturas
      const usadas = {};
      const intervalos = [];
      for (let i = 0; i < lista.length; i++) {
        const raw = Array.isArray(lista[i].paginas) ? lista[i].paginas : [];
        const pags = [];
        for (const v of raw) {
          const p = parseInt(v, 10);
          if (!(p >= 1 && p <= n) || pags.indexOf(p) !== -1) return null;
          if (usadas[p]) return null;
          pags.push(p);
        }
        if (!pags.length) return null;
        pags.sort((x, y) => x - y);
        pags.forEach((p) => (usadas[p] = true));
        // 1,2,3,5 -> "1-3,5"
        const partesTxt = [];
        let ini = pags[0];
        let prev = pags[0];
        for (let k = 1; k <= pags.length; k++) {
          if (k < pags.length && pags[k] === prev + 1) {
            prev = pags[k];
            continue;
          }
          partesTxt.push(ini === prev ? String(ini) : ini + '-' + prev);
          if (k < pags.length) {
            ini = pags[k];
            prev = pags[k];
          }
        }
        intervalos.push(partesTxt.join(','));
      }

      tmp = String(app.dataDir()) + '/.split_' + $security.randomString(10);
      $os.mkdirAll(tmp, 0o755);
      const base = nomeOrig.replace(/\.pdf$/i, '');
      const ficheiros = [];
      for (let i = 0; i < intervalos.length; i++) {
        const saida = tmp + '/parte' + (i + 1) + '.pdf';
        $os.cmd('qpdf', '--empty', '--pages', origem, intervalos[i], '--', saida).output();
        ficheiros.push($filesystem.fileFromBytes($os.readFile(saida), base + '_parte' + (i + 1) + '.pdf'));
      }
      return ficheiros;
    } catch (err) {
      console.log('[faturas] não foi possível dividir o PDF: ' + String(err).substring(0, 160));
      return null;
    } finally {
      if (tmp) {
        try {
          $os.removeAll(tmp);
        } catch (_) {}
      }
    }
  };


  const partes = dividirPdf(app, origem, nomeOrig, lista);
  const colecao = app.findCollectionByNameOrId('faturas');
  let bytesOrig = null;
  const ids = [];
  let duplicadas = 0;
  for (let i = 0; i < lista.length; i++) {
    let rec = fatura;
    if (i > 0) {
      rec = new Record(colecao);
      rec.set('empresa', empresaId);
      rec.set('autor', fatura.getString('autor'));
      rec.set('tipo', tipo);
      rec.set('estado', 'nova');
    }
    const pags = Array.isArray(lista[i].paginas) ? lista[i].paginas.join(',') : '';
    if (partes) {
      rec.set('ficheiro', partes[i]);
      rec.set('notas', 'Parte ' + (i + 1) + ' de ' + lista.length + ' do PDF original (págs. ' + pags + ').');
    } else {
      // não deu para cortar: cada fatura fica com o ficheiro inteiro e um aviso
      if (i > 0 && origem) {
        try {
          if (!bytesOrig) bytesOrig = $os.readFile(origem);
          rec.set('ficheiro', $filesystem.fileFromBytes(bytesOrig, nomeOrig));
        } catch (_) {}
      }
      rec.set(
        'notas',
        'Ficheiro com ' + lista.length + ' faturas (págs. ' + pags + '); não foi possível separá-las. Confere as páginas.',
      );
    }
    const dup = aplicar(rec, lista[i], true);
    if (dup) duplicadas++;
    ids.push(rec.id);
  }

  return {
    ok: true,
    provider: r.provider,
    dados: lista[0],
    faturas: ids,
    dividido: !!partes,
    duplicadas: duplicadas,
  };
}

module.exports = { analisarFatura };
