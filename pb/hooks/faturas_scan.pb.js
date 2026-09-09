/// <reference path="../pb_data/types.d.ts" />

// Ingestão automática de faturas digitalizadas por um scanner.
//
// O scanner larga os PDFs/fotos numa pasta partilhada (scan-to-folder). De 5
// em 5 minutos, o cron cria uma `faturas` (estado 'nova') por cada ficheiro,
// manda-a analisar pela IA e move o original para `<pasta>/processadas/`.
//
//   TURNKEY_SCAN_DIR       pasta que o scanner alimenta (ex.: D:\scan\faturas)
//   TURNKEY_SCAN_EMPRESA   id da empresa a que as faturas pertencem
//
// Sem estas duas variáveis o cron não faz nada.

cronAdd('scan_faturas', '*/5 * * * *', () => {
  const dir = $os.getenv('TURNKEY_SCAN_DIR');
  const empId = $os.getenv('TURNKEY_SCAN_EMPRESA');
  if (!dir || !empId) return;

  try {
    $app.findRecordById('empresas', empId);
  } catch (_) {
    console.log('[scan] TURNKEY_SCAN_EMPRESA inválida: ' + empId);
    return;
  }

  let entries;
  try {
    entries = $os.readDir(dir);
  } catch (err) {
    console.log('[scan] não consigo ler ' + dir + ': ' + err);
    return;
  }

  const proc = dir + '/processadas';
  try {
    $os.mkdirAll(proc, 0o755);
  } catch (_) {}

  const okExt = /\.(jpe?g|png|webp|pdf)$/i;
  const mimeDe = (n) =>
    /\.png$/i.test(n)
      ? 'image/png'
      : /\.webp$/i.test(n)
        ? 'image/webp'
        : /\.pdf$/i.test(n)
          ? 'application/pdf'
          : 'image/jpeg';

  const core = require(`${__hooks}/faturas_core.js`);
  const col = $app.findCollectionByNameOrId('faturas');
  let feitas = 0;

  for (const en of entries) {
    let nome;
    try {
      nome = en.name ? en.name() : String(en);
      if (en.isDir && en.isDir()) continue;
    } catch (_) {
      continue;
    }
    if (!okExt.test(nome)) continue;

    const full = dir + '/' + nome;
    try {
      const bytes = $os.readFile(full);
      if (!bytes || !bytes.length) continue;
      const b64 = Buffer.from(bytes).toString('base64');

      const rec = new Record(col);
      rec.set('empresa', empId);
      rec.set('tipo', 'fatura');
      rec.set('estado', 'nova');
      rec.set('notas', 'Scanner: ' + nome);
      rec.set('ficheiro', $filesystem.fileFromBytes(bytes, nome));
      $app.save(rec);

      // analisa já (503 sem chave -> fica 'nova', o utilizador revê depois)
      core.analisarFatura($app, rec.id, {
        imagemBase64: b64,
        mime: mimeDe(nome),
      });

      try {
        $os.rename(full, proc + '/' + Date.now() + '_' + nome);
      } catch (err) {
        console.log('[scan] não movi ' + nome + ': ' + err);
      }
      feitas++;
    } catch (err) {
      console.log('[scan] ' + nome + ': ' + err);
    }
  }

  if (feitas > 0) console.log('[scan] ' + feitas + ' fatura(s) importada(s).');
});
